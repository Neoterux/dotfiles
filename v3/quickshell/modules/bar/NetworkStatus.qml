import QtQuick
import Quickshell.Io

// Icono de red (solo icono, sin texto): wifi o ethernet segun el nombre
// de la interfaz con la ruta por defecto. Esta maquina no tiene
// NetworkManager corriendo (nmcli ni siquiera esta instalado), asi que en
// vez de replicar el nmcli de waybar se usa `ip -j route show default`,
// que solo depende de iproute2 y funciona igual con NetworkManager,
// systemd-networkd o nada.
IconButton {
    id: root

    property bool online: false
    property string iface: ""

    // Cableado: md-ethernet (el puerto RJ45), no fa-plug -- ese es un
    // enchufe/conector generico y no se lee como "red por cable".
    icon: online ? (iface.startsWith("wl") ? "\u{f1eb}" : "\u{f0200}") : "\u{f092d}"
    active: online
    fontScale: online && !iface.startsWith("wl") ? 1.05 : 1.15

    Process {
        id: proc
        command: ["ip", "-j", "route", "show", "default"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const routes = JSON.parse(text);
                    if (routes.length > 0) {
                        root.online = true;
                        root.iface = routes[0].dev;
                    } else {
                        root.online = false;
                        root.iface = "";
                    }
                } catch (e) {
                    root.online = false;
                    root.iface = "";
                }
            }
        }
    }

    Process {
        id: nmtui
        command: ["kitty", "--", "nmtui"]
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            proc.running = false;
            proc.running = true;
        }
    }

    onLeftClicked: nmtui.startDetached()
}
