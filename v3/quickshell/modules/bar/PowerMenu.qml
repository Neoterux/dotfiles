import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "../drawer"

// Menu de apagado: lock / logout / reboot / shutdown / suspend.
// IMPORTANTE: estas acciones son irreversibles/disruptivas -- por eso
// cada boton pide confirmacion (un segundo click) en vez de disparar
// directo, salvo "lock" que es inofensivo.
IconButton {
    id: root

    required property var panelWindow
    property bool expanded: false
    property string armed: ""

    icon: "\u{f011}" // nf-fa-power_off

    onLeftClicked: {
        root.expanded = !root.expanded;
        root.armed = "";
    }

    Process {
        id: lockProc
        command: ["hyprlock"]
    }

    Process {
        id: logoutProc
        command: ["hyprctl", "dispatch", "hl.dsp.exit()"]
    }

    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }

    Process {
        id: poweroffProc
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
    }

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        RowLayout {
            spacing: 10 * root.uiScale

            PowerMenuButton {
                uiScale: root.uiScale
                icon: "\u{f023}"
                label: "bloquear"
                onActivated: {
                    lockProc.startDetached();
                    root.expanded = false;
                }
            }

            PowerMenuButton {
                uiScale: root.uiScale
                icon: "\u{f08b}"
                label: "salir"
                needsConfirm: true
                armed: root.armed === "logout"
                onArm: root.armed = "logout"
                onActivated: {
                    logoutProc.startDetached();
                    root.expanded = false;
                }
            }

            PowerMenuButton {
                uiScale: root.uiScale
                icon: "\u{f021}"
                label: "reiniciar"
                needsConfirm: true
                armed: root.armed === "reboot"
                onArm: root.armed = "reboot"
                onActivated: {
                    rebootProc.startDetached();
                    root.expanded = false;
                }
            }

            PowerMenuButton {
                uiScale: root.uiScale
                icon: "\u{f186}"
                label: "suspender"
                onActivated: {
                    suspendProc.startDetached();
                    root.expanded = false;
                }
            }

            PowerMenuButton {
                uiScale: root.uiScale
                icon: "\u{f011}"
                label: "apagar"
                needsConfirm: true
                armed: root.armed === "poweroff"
                onArm: root.armed = "poweroff"
                onActivated: {
                    poweroffProc.startDetached();
                    root.expanded = false;
                }
            }
        }
    }
}
