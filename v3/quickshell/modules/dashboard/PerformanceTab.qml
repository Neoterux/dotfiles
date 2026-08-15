import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"

// Pestaña "Performance": uso/temperatura de CPU, GPU y memoria. Los
// sensores de temperatura salen de /sys/class/hwmon (k10temp / amdgpu en
// esta maquina), resueltos dinamicamente en vez de hardcodear "hwmon0"
// porque ese numero puede cambiar entre reinicios.
RowLayout {
    id: root
    spacing: 24 * uiScale

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

    FileView {
        id: statFile
        path: "/proc/stat"
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
    }

    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
    }

    FileView {
        id: cpuFreqFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
    }

    FileView {
        id: cpuFreqMaxFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
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

    Component.onCompleted: hwmonDetect.running = true

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.sampleCpu();
            root.sampleMem();
            root.sampleTemps();
            root.sampleFreq();
        }
    }

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
