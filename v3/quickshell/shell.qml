import QtQuick
import Quickshell
import "modules/bar" as Bar
import "modules/notifications" as Notif

// Punto de entrada de Quickshell (equivalente al `waybar/config` +
// `style.css`, pero programable). Levanta una barra flotante por cada
// monitor conectado, replicando los modulos que ya tenias en waybar:
// launcher, backlight, volumen | workspaces | red, cpu, memoria, reloj.
//
// Para probarla sin tocar el waybar que ya tenes corriendo:
//   quickshell -p ~/.config/quickshell
// Para que sea la config por defecto (la que arranca con `qs`/`quickshell`
// a secas) ya alcanza con que viva en ~/.config/quickshell/shell.qml.
ShellRoot {
    // Tabla de escala por monitor: 1.0 = tamaño base (barra de ~26px).
    // Se busca por nombre de output (el mismo que usan `hyprctl monitors`
    // y monitors.conf, p.ej. "DP-1"/"DP-3"). Cualquier monitor que no este
    // en la tabla usa `default`.
    property var monitorScale: ({
        "default": 1.0,
        'DP-1': 0.9,
        'DP-3': 0.8
    })

    function scaleFor(screenName) {
        return monitorScale[screenName] !== undefined ? monitorScale[screenName] : monitorScale["default"];
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            readonly property real uiScale: scaleFor(modelData.name)

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: Math.round(30 * uiScale)
            color: "transparent"

            // Barra a todo lo ancho, pegada al borde (sin margenes/gap
            // como antes -- ver Bar.qml para el look sin bordes).
            margins {
                top: 0
                left: 0
                right: 0
            }

            Bar.Bar {
                anchors.fill: parent
                uiScale: panel.uiScale
                // Los dropdowns (calendario, etc.) necesitan la PanelWindow
                // como parentWindow para poder anclarse correctamente.
                panelWindow: panel
            }
        }
    }

    // Toasts de notificaciones nuevas -- una sola ventana, en el primer
    // monitor detectado (no una por monitor: son efimeros, duplicarlos no
    // suma nada y complica rutear cual "es el que importa" por foco).
    Notif.NotificationPopupWindow {
        panelScreen: Quickshell.screens[0]
        uiScale: scaleFor(Quickshell.screens[0] ? Quickshell.screens[0].name : "default")
    }
}
