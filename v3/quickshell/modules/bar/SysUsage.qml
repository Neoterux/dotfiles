pragma Singleton
import QtQuick
import Quickshell.Io

// Uso de CPU y memoria + su historial, para los graficos de la barra
// (Usage.qml). Singleton por lo mismo que TempSensors: una barra por
// monitor, un solo muestreo.
//
// Leer /proc/stat y /proc/meminfo es leer memoria del kernel (no despierta
// ningun dispositivo), asi que 2s no cuesta nada y el grafico se ve
// continuo. `.reload()` + `onLoaded`, no `.text()` a secas -- ver el
// gotcha de FileView en v3/CLAUDE.md.
QtObject {
    id: root

    readonly property int interval: 2000
    // 45 muestras x 2s = el ultimo minuto y medio.
    readonly property int historyLen: 45

    // 0..1
    property real cpu: 0
    property real mem: 0
    property real swap: 0
    property var cpuHistory: []
    property var memHistory: []

    // En GiB, para el drawer.
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0

    property real prevTotal: -1
    property real prevIdle: -1

    readonly property FileView statFile: FileView {
        path: "/proc/stat"
        onLoaded: root.sampleCpu()
    }

    readonly property FileView memFile: FileView {
        path: "/proc/meminfo"
        onLoaded: root.sampleMem()
    }

    readonly property Timer timer: Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.statFile.reload();
            root.memFile.reload();
        }
    }

    function push(history, v) {
        return [...history, v].slice(-root.historyLen);
    }

    function sampleCpu() {
        const line = root.statFile.text().split("\n")[0];
        const fields = line.trim().split(/\s+/).slice(1).map(Number);
        // idle + iowait cuentan como "no usado".
        const idle = fields[3] + (fields[4] || 0);
        const total = fields.reduce((a, b) => a + b, 0);

        if (root.prevTotal >= 0) {
            const totalDelta = total - root.prevTotal;
            if (totalDelta > 0) {
                root.cpu = Math.max(0, Math.min(1, 1 - (idle - root.prevIdle) / totalDelta));
                root.cpuHistory = root.push(root.cpuHistory, root.cpu);
            }
        }
        root.prevTotal = total;
        root.prevIdle = idle;
    }

    function sampleMem() {
        const v = {};
        for (const line of root.memFile.text().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                v[m[1]] = Number(m[2]);
        }
        const total = v.MemTotal || 0;
        if (total <= 0)
            return;
        // MemAvailable y no MemFree: la cache de disco se libera sola,
        // contarla como "usada" daria 90% todo el tiempo.
        const available = v.MemAvailable !== undefined ? v.MemAvailable : total;
        root.mem = Math.max(0, Math.min(1, 1 - available / total));
        root.memHistory = root.push(root.memHistory, root.mem);
        root.memUsedGiB = (total - available) / 1048576;
        root.memTotalGiB = total / 1048576;

        const swapTotal = v.SwapTotal || 0;
        const swapUsed = swapTotal - (v.SwapFree || 0);
        root.swapTotalGiB = swapTotal / 1048576;
        root.swapUsedGiB = swapUsed / 1048576;
        root.swap = swapTotal > 0 ? swapUsed / swapTotal : 0;
    }
}
