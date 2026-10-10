pragma Singleton
import QtQuick
import Quickshell.Io
import "../../theme"

// Temperaturas de /sys/class/hwmon, compartidas por las barras de todos los monitores.
QtObject {
    id: root

    property var sensors: []
    // [{ key, title, icon, tint, sensors }]
    property var barEntries: []
    // [{ title, subtitle, sensors }], uno por chip
    property var devices: []

    readonly property int fastInterval: 3000
    // Leer un NVMe lo saca de APST; mas lento para no mantenerlo despierto.
    readonly property int slowInterval: 15000

    readonly property Process discovery: Process {
        running: true
        // dir|input|chip|label|model
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

    function classify(chip, label) {
        const l = label.toLowerCase();
        if (chip === "k10temp" || chip === "zenpower" || chip === "coretemp") {
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
        const byKind = (a, b) => a.order - b.order || a.title.localeCompare(b.title);
        root.devices = Object.values(devices).sort(byKind);
        root.barEntries = Object.values(entries).sort(byKind);
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
            return Colors.network;
        case "vram":
            return Colors.memory;
        case "nvme":
            return Colors.backlight;
        }
        return Colors.fg;
    }
}
