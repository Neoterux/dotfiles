pragma Singleton
import QtQuick
import Quickshell.Io
import "../../theme"

// Lectura compartida de todas las temperaturas de /sys/class/hwmon.
//
// Singleton y no dentro de Temps.qml porque hay una barra por monitor:
// con el polling adentro del modulo cada barra leeria los mismos archivos
// por su cuenta. Asi hay un solo juego de FileView y un solo Timer, y
// todas las barras (y su drawer) bindean a los mismos objetos.
//
// Los sensores se descubren UNA vez al arrancar (los numeros hwmonN
// cambian entre reinicios, pero no durante la sesion) y despues solo se
// releen los `temp*_input`, sin spawnear procesos por tick. Nada esta
// hardcodeado a esta maquina: lo que no se reconoce igual aparece en el
// drawer, solo no gana lugar en la barra.
QtObject {
    id: root

    // Un FileView por sensor (ver `sensorComponent`), en el orden en que
    // los devolvio el descubrimiento.
    property var sensors: []

    // Lo que se muestra en la barra: [{ key, title, icon, tint, sensors }].
    // Un entry puede llevar mas de un sensor (GPU: borde/hotspot).
    property var barEntries: []

    // Lo que se muestra en el drawer: [{ title, subtitle, sensors }], un
    // grupo por chip hwmon.
    property var devices: []

    // CPU y GPU cambian rapido; el polling va mas suelto que los 2s del
    // dashboard porque esto corre SIEMPRE, no solo con el drawer abierto.
    readonly property int fastInterval: 3000
    // Leer la temperatura de un NVMe no es leer memoria: el driver le
    // manda un comando (SMART log) al controlador, que lo saca de su
    // estado de bajo consumo (APST). Cada 3s eso mantendria los discos
    // despiertos y mas calientes -- justo lo contrario de lo que se busca.
    // Ademas el Fanxiang (IG5236) de esta maquina tiene firmware fragil:
    // menos comandos, mejor. La temperatura de un disco cambia lento.
    readonly property int slowInterval: 15000

    readonly property Process discovery: Process {
        running: true
        // Una linea por sensor: dir|input|chip|label|model. `-r` descarta
        // el glob literal cuando un chip no tiene ningun temp*_input (p.ej.
        // la bateria del mouse, que tambien es un hwmon).
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do c=$(cat \"$d/name\" 2>/dev/null); m=$(cat \"$d/device/model\" 2>/dev/null | sed 's/ *$//'); for t in \"$d\"/temp*_input; do [ -r \"$t\" ] || continue; l=$(cat \"${t%_input}_label\" 2>/dev/null); echo \"$d|$t|$c|$l|$m\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: root.build(text)
        }
    }

    readonly property Timer fastTimer: Timer {
        interval: root.fastInterval
        running: root.sensors.length > 0
        repeat: true
        onTriggered: root.reloadWhere(s => !s.slow)
    }

    readonly property Timer slowTimer: Timer {
        interval: root.slowInterval
        running: root.sensors.length > 0
        repeat: true
        onTriggered: root.reloadWhere(s => s.slow)
    }

    // `.reload()` explicito y el valor se toma en `onLoaded`: llamar
    // `.text()` de nuevo NO relee el archivo (ver v3/CLAUDE.md, gotcha de
    // FileView).
    property Component sensorComponent: Component {
        FileView {
            id: sensor

            property string dir
            property string chip
            property string label
            property string model
            property bool slow: false
            property bool onBar: false
            property real warn: 80
            property real hot: 95
            // NaN hasta la primera lectura; la UI muestra "—".
            property real celsius: NaN

            onLoaded: {
                const v = Number(sensor.text().trim());
                if (!isNaN(v))
                    sensor.celsius = Math.round(v / 1000);
            }
        }
    }

    function reloadWhere(pred) {
        for (const s of root.sensors) {
            if (pred(s))
                s.reload();
        }
    }

    // Que sensor es cual y cuando pasa a amarillo/rojo. Umbrales por tipo:
    // un NVMe a 70 ya esta throttleando, una GPU a 70 esta tranquila.
    function classify(chip, label) {
        const l = label.toLowerCase();
        if (chip === "k10temp" || chip === "zenpower" || chip === "coretemp") {
            // Tctl/Tdie (AMD) o Package (Intel) es "la" temperatura de la
            // CPU; los Tccd/Core N son detalle para el drawer.
            return {
                kind: "cpu",
                onBar: /tctl|tdie|package/.test(l) || l === "",
                warn: 75,
                hot: 85
            };
        }
        if (chip === "amdgpu") {
            if (l === "junction")
                return { kind: "gpu", onBar: true, warn: 90, hot: 100 };
            if (l === "mem")
                return { kind: "vram", onBar: true, warn: 85, hot: 95 };
            return { kind: "gpu", onBar: l === "edge" || l === "", warn: 75, hot: 90 };
        }
        if (chip === "nvme")
            return { kind: "nvme", onBar: l === "composite" || l === "", warn: 60, hot: 70, slow: true };
        return { kind: "other", onBar: false, warn: 80, hot: 95 };
    }

    function build(text) {
        const order = { cpu: 0, gpu: 1, vram: 2, nvme: 3 };
        const sensors = [];
        const entries = {};
        const devices = {};

        for (const line of text.trim().split("\n")) {
            const [dir, input, chip, label, model] = line.split("|");
            if (!input)
                continue;
            const c = root.classify(chip, label || "");
            const s = root.sensorComponent.createObject(root, {
                path: input,
                dir,
                chip,
                label: label || "",
                model: model || "",
                slow: c.slow === true,
                onBar: c.onBar,
                warn: c.warn,
                hot: c.hot
            });
            sensors.push(s);

            if (!devices[dir]) {
                devices[dir] = {
                    order: order[c.kind] ?? 4,
                    title: model || root.deviceTitle(chip),
                    subtitle: chip,
                    sensors: []
                };
            }
            devices[dir].sensors.push(s);

            if (c.onBar) {
                // Borde y hotspot de la misma GPU comparten entry
                // ("33/39°"); la VRAM va aparte, con su propio icono.
                const key = c.kind + "|" + dir;
                if (!entries[key]) {
                    entries[key] = {
                        key,
                        order: order[c.kind],
                        title: model || root.deviceTitle(chip),
                        icon: root.iconFor(c.kind),
                        tint: root.tintFor(c.kind),
                        sensors: []
                    };
                }
                entries[key].sensors.push(s);
            }
        }

        root.sensors = sensors;
        // Mismo orden en la barra y en el drawer (CPU, GPU, VRAM, discos;
        // los discos por nombre), para que cada numero de la barra se
        // encuentre en el drawer sin buscar. Sin esto el drawer salia en
        // orden de hwmonN, que es el orden en que cargaron los drivers.
        const byKind = (a, b) => a.order - b.order || a.title.localeCompare(b.title);
        root.devices = Object.values(devices).sort(byKind);
        root.barEntries = Object.values(entries).sort(byKind);
        // Primera lectura ya, sin esperar al primer tick.
        root.reloadWhere(() => true);
    }

    function deviceTitle(chip) {
        if (chip === "k10temp" || chip === "zenpower" || chip === "coretemp")
            return "CPU";
        if (chip === "amdgpu")
            return "GPU";
        return chip;
    }

    function iconFor(kind) {
        switch (kind) {
        case "cpu":
            return "\u{f2db}"; // nf-fa-microchip
        case "gpu":
            return "\u{f08ae}"; // nf-md-expansion_card
        case "vram":
            return "\u{f035b}"; // nf-md-memory
        case "nvme":
            return "\u{f02ca}"; // nf-md-harddisk
        }
        return "\u{f2c9}"; // nf-fa-thermometer_half
    }

    function tintFor(kind) {
        switch (kind) {
        case "cpu":
            return Colors.cpu;
        case "gpu":
            // el mismo rojo que la GPU en dashboard/PerformanceTab.qml
            return Colors.network;
        case "vram":
            return Colors.memory;
        case "nvme":
            return Colors.backlight;
        }
        return Colors.fg;
    }
}
