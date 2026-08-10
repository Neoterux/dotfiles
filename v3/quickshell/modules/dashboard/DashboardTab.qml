import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"

// Pestaña "Dashboard": info del sistema + calendario, lado a lado (como
// las tarjetas del showcase de quickshell.org, sin la de clima porque no
// tengo ninguna API de clima conectada).
RowLayout {
    id: root
    spacing: 20 * uiScale

    property real uiScale: 1.0
    property string distro: ""
    property string uptimeText: ""

    // Llamar FileView.text() dentro de un binding declarativo NO
    // reacciona cuando termina la carga async (probado con el hostname
    // del reloj, se quedaba pegado en vacio). La forma confiable es
    // escuchar `onLoaded`/`onTextChanged` explicitamente.
    function sampleUptime() {
        const secs = Math.floor(Number(uptimeFile.text().split(" ")[0]) || 0);
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        root.uptimeText = h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    Process {
        id: distroProc
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\""]
        stdout: StdioCollector {
            onStreamFinished: root.distro = text.trim()
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.sampleUptime()
        onTextChanged: root.sampleUptime()
    }

    Component.onCompleted: distroProc.running = true

    // /proc/uptime no dispara file-watch (procfs no soporta inotify para
    // esto), asi que ademas se fuerza una relectura cada minuto.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            uptimeFile.reload();
            root.sampleUptime();
        }
    }

    ColumnLayout {
        Layout.preferredWidth: 190 * root.uiScale
        Layout.fillHeight: true
        spacing: 12 * root.uiScale

        Text {
            text: "sistema"
            color: Colors.fg
            opacity: 0.5
            font.family: Colors.fontFamily
            font.pixelSize: 12 * root.uiScale
            font.bold: true
        }

        RowLayout {
            spacing: 8 * root.uiScale
            Text {
                text: "" // nf-fa-linux
                color: Colors.accent
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
            }
            Text {
                Layout.fillWidth: true
                text: root.distro
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                elide: Text.ElideRight
            }
        }

        RowLayout {
            spacing: 8 * root.uiScale
            Text {
                text: "" // nf-fa-desktop
                color: Colors.accent
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
            }
            Text {
                text: "Hyprland"
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
            }
        }

        RowLayout {
            spacing: 8 * root.uiScale
            Text {
                text: "" // nf-fa-clock_o
                color: Colors.accent
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
            }
            Text {
                text: "up " + root.uptimeText
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        color: Colors.workspaceBorder
        opacity: 0.25
    }

    Calendar {
        uiScale: root.uiScale
        Layout.fillWidth: true
    }
}
