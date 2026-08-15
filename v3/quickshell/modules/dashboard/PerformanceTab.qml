import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"

// Pestaña "Performance": uso/temperatura de CPU, GPU y memoria, uso de
// disco y actividad de lectura/escritura. Los sensores de temperatura
// salen de /sys/class/hwmon (k10temp / amdgpu en esta maquina), resueltos
// dinamicamente en vez de hardcodear "hwmon0" porque ese numero puede
// cambiar entre reinicios.
ColumnLayout {
    id: root
    spacing: 18 * uiScale

    property real uiScale: 1.0
    property real cpuUsage: 0
    property real memUsage: 0
    property real cpuTempC: 0
    property real gpuTempC: 0
    property string memUsedText: ""
    property string memTotalText: ""

    property real prevTotal: -1
    property real prevIdle: -1
    property string cpuTempPath: ""
    property string gpuTempPath: ""

    // "Energia": esta maquina no tiene sensor de consumo (watts) --
    // ni RAPL ni power1_input en amdgpu/k10temp -- asi que se usa la
    // frecuencia actual de la CPU como proxy del estado energetico.
    property real cpuFreqGhz: 0
    property real cpuFreqMaxGhz: 1

    // Uso de disco (df, cada 30s -- cambia lento, no hace falta la
    // cadencia de 2s del resto) y actividad de IO (/proc/diskstats, mismo
    // timer de 2s que CPU/mem).
    property var disks: []
    property var diskNames: []
    property real prevReadSectors: -1
    property real prevWriteSectors: -1
    property real prevIoTime: -1
    property var ioReadHistory: []
    property var ioWriteHistory: []
    readonly property int ioHistoryLen: 40

    // OJO -- gotcha real, no obvio: `FileView.text()` NO relee el archivo
    // solo por llamarlo de nuevo. `text()` reasigna `path` a si mismo, y
    // si el path no cambio el setter de abajo no dispara una recarga --
    // asi que sondear un mismo FileView con un Timer llamando `.text()`
    // cada vez devuelve SIEMPRE el contenido de la primerca carga (quedo
    // "congelado"), confirmado en vivo generando carga real de CPU/disco
    // y viendo que los anillos no se movian ni un poco. Con /proc/*, que
    // no dispara `watchChanges` (inotify) de forma confiable porque el
    // contenido se regenera al leer en vez de "cambiar" de verdad, hace
    // falta `.reload()` explicito + `onLoaded` para efectivamente releer.
    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.sampleCpu()
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root.sampleMem()
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        onLoaded: root.sampleTemps()
    }

    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        onLoaded: root.sampleTemps()
    }

    FileView {
        id: cpuFreqFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
        onLoaded: root.sampleFreq()
    }

    FileView {
        id: cpuFreqMaxFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
        onLoaded: root.sampleFreq()
    }

    FileView {
        id: diskstatsFile
        path: "/proc/diskstats"
        onLoaded: root.sampleIo()
    }

    // /sys/block/* -- una entrada por disco *entero* (sda, nvme0n1, ...),
    // sin las particiones -- se usa para filtrar /proc/diskstats y no
    // contar cada particion Y el disco entero (eso duplicaria el total).
    Process {
        id: blockListProc
        command: ["ls", "/sys/block"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.diskNames = text.trim().split("\n").filter(s => s.length > 0);
            }
        }
    }

    // Particiones montadas reales: se excluyen los filesystems virtuales
    // (tmpfs, proc, overlay de contenedores, etc.) para no listar cosas
    // que no son "un disco" para el usuario.
    Process {
        id: dfProc
        command: ["df", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs", "-x", "overlay", "-x", "proc", "-x", "sysfs", "-x", "cgroup2", "-x", "tracefs", "-x", "debugfs", "-x", "devpts", "-x", "mqueue", "-x", "efivarfs", "--output=source,fstype,size,used,avail,target"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").slice(1);
                const disks = [];
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 6)
                        continue;
                    const [source, fstype, size, used, avail, ...targetParts] = parts;
                    disks.push({
                        source,
                        fstype,
                        size: Number(size),
                        used: Number(used),
                        avail: Number(avail),
                        target: targetParts.join(" "),
                    });
                }
                root.disks = disks;
            }
        }
    }

    Process {
        id: hwmonDetect
        // Recorre /sys/class/hwmon/*/name buscando k10temp (CPU AMD) y
        // amdgpu (GPU), imprime "k10temp:<ruta>" y "amdgpu:<ruta>" para
        // parsear el resultado.
        command: ["sh", "-c", "for d in /sys/class/hwmon/*/; do n=$(cat \"$d/name\" 2>/dev/null); if [ \"$n\" = k10temp ]; then echo \"cpu:${d}temp1_input\"; fi; if [ \"$n\" = amdgpu ]; then f=\"${d}temp2_input\"; [ -f \"$f\" ] || f=\"${d}temp1_input\"; echo \"gpu:$f\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const [kind, path] = line.split(":");
                    if (kind === "cpu")
                        root.cpuTempPath = path;
                    else if (kind === "gpu")
                        root.gpuTempPath = path;
                }
            }
        }
    }

    function sampleCpu() {
        const line = statFile.text().split("\n")[0];
        const fields = line.trim().split(/\s+/).slice(1).map(Number);
        const idle = fields[3] + (fields[4] || 0);
        const total = fields.reduce((a, b) => a + b, 0);

        if (root.prevTotal >= 0) {
            const totalDelta = total - root.prevTotal;
            const idleDelta = idle - root.prevIdle;
            if (totalDelta > 0)
                root.cpuUsage = Math.max(0, Math.min(1, 1 - idleDelta / totalDelta));
        }
        root.prevTotal = total;
        root.prevIdle = idle;
    }

    function sampleMem() {
        const values = {};
        for (const line of memFile.text().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                values[m[1]] = Number(m[2]);
        }
        const total = values.MemTotal || 0;
        const available = values.MemAvailable !== undefined ? values.MemAvailable : total;
        if (total > 0) {
            root.memUsage = Math.max(0, Math.min(1, 1 - available / total));
            root.memUsedText = (((total - available) / 1048576).toFixed(1)) + "GiB";
            root.memTotalText = ((total / 1048576).toFixed(0)) + "GiB";
        }
    }

    function sampleTemps() {
        if (root.cpuTempPath)
            root.cpuTempC = Math.round(Number(cpuTempFile.text().trim()) / 1000);
        if (root.gpuTempPath)
            root.gpuTempC = Math.round(Number(gpuTempFile.text().trim()) / 1000);
    }

    function sampleFreq() {
        try {
            root.cpuFreqGhz = Number(cpuFreqFile.text().trim()) / 1000000;
            root.cpuFreqMaxGhz = Number(cpuFreqMaxFile.text().trim()) / 1000000;
        } catch (e) {
            // sin cpufreq (poco probable, pero por si acaso)
        }
    }

    function sampleIo() {
        if (root.diskNames.length === 0)
            return;

        const names = {};
        for (const n of root.diskNames)
            names[n] = true;

        let readSectors = 0;
        let writeSectors = 0;
        for (const line of diskstatsFile.text().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f.length < 11 || !names[f[2]])
                continue;
            readSectors += Number(f[5]);
            writeSectors += Number(f[9]);
        }

        const now = Date.now();
        if (root.prevIoTime >= 0) {
            const dt = (now - root.prevIoTime) / 1000;
            if (dt > 0) {
                // Sectores son siempre de 512 bytes, independientemente
                // del tamaño de bloque real del disco (asi lo define
                // /proc/diskstats, no es especifico de esta maquina).
                const readBps = ((readSectors - root.prevReadSectors) * 512) / dt;
                const writeBps = ((writeSectors - root.prevWriteSectors) * 512) / dt;
                root.ioReadHistory = [...root.ioReadHistory, Math.max(0, readBps)].slice(-root.ioHistoryLen);
                root.ioWriteHistory = [...root.ioWriteHistory, Math.max(0, writeBps)].slice(-root.ioHistoryLen);
            }
        }
        root.prevReadSectors = readSectors;
        root.prevWriteSectors = writeSectors;
        root.prevIoTime = now;
    }

    Component.onCompleted: {
        hwmonDetect.running = true;
        blockListProc.running = true;
        dfProc.running = true;
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (root.cpuTempPath)
                cpuTempFile.reload();
            if (root.gpuTempPath)
                gpuTempFile.reload();
            cpuFreqFile.reload();
            cpuFreqMaxFile.reload();
            diskstatsFile.reload();
        }
    }

    // El uso de disco cambia lento -- 30s alcanza de sobra, no hace
    // falta la cadencia de 2s del resto de las metricas. Toggle
    // false->true (no solo `= true`) para forzar el reinicio del
    // Process aunque ya haya terminado -- mismo patron que usa el
    // Timer de NetworkStatus.qml.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            dfProc.running = false;
            dfProc.running = true;
        }
    }

    RowLayout {
        spacing: 24 * root.uiScale

        MetricCard {
            uiScale: root.uiScale
            label: "GPU"
            tint: Colors.network

            RingGauge {
                uiScale: root.uiScale
                size: 106
                value: root.gpuTempC / 100
                ringColor: Colors.network
                bigText: root.gpuTempPath ? (root.gpuTempC + "°C") : "—"
            }
        }

        MetricCard {
            uiScale: root.uiScale
            label: "CPU"
            tint: Colors.cpu

            RingGauge {
                uiScale: root.uiScale
                size: 106
                value: root.cpuUsage
                ringColor: Colors.cpu
                bigText: root.cpuTempPath ? (root.cpuTempC + "°C") : Math.round(root.cpuUsage * 100) + "%"
                smallText: root.cpuTempPath ? (Math.round(root.cpuUsage * 100) + "% uso") : ""
            }
        }

        MetricCard {
            uiScale: root.uiScale
            label: "RAM"
            tint: Colors.memory

            RingGauge {
                uiScale: root.uiScale
                size: 106
                value: root.memUsage
                ringColor: Colors.memory
                bigText: root.memUsedText
                smallText: "de " + root.memTotalText
            }
        }

        MetricCard {
            uiScale: root.uiScale
            label: "Reloj"
            tint: Colors.accent

            RingGauge {
                uiScale: root.uiScale
                size: 106
                value: root.cpuFreqMaxGhz > 0 ? root.cpuFreqGhz / root.cpuFreqMaxGhz : 0
                ringColor: Colors.accent
                bigText: root.cpuFreqGhz.toFixed(1) + "GHz"
                smallText: root.cpuFreqMaxGhz > 0 ? ("max " + root.cpuFreqMaxGhz.toFixed(1) + "GHz") : ""
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.workspaceBorder
        opacity: 0.25
    }

    Text {
        text: "Actividad de disco"
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.bold: true
    }

    IOGraph {
        Layout.fillWidth: true
        Layout.preferredWidth: 420 * root.uiScale
        uiScale: root.uiScale
        readHistory: root.ioReadHistory
        writeHistory: root.ioWriteHistory
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.workspaceBorder
        opacity: 0.25
    }

    Text {
        text: "Discos"
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.bold: true
    }

    DiskUsageSection {
        Layout.fillWidth: true
        Layout.preferredWidth: 420 * root.uiScale
        uiScale: root.uiScale
        disks: root.disks
    }
}
