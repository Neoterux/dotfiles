import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import "../../theme"

// Equivalente a "hyprland/workspaces" de waybar, pero reactivo via la IPC
// nativa de Quickshell (Hyprland.workspaces) en vez de leer el socket a mano.
//
// Regla de que se muestra en cada pill (pedido explicito, no derivable del
// codigo): si el workspace no tiene ventanas Y no esta enfocado, un simple
// punto. Si tiene ventanas (sin importar si esta enfocado) muestra el
// icono de su app; si esta enfocado pero vacio, o el icono no se pudo
// resolver, cae al numero/nombre del workspace. El contenedor entero (no
// cada pill) se tiñe con el color de "workspace activo" bien translucido,
// como fondo glass compartido.
Pill {
    id: root
    bg: Colors.workspaceActiveBgTranslucent
    fg: Colors.fg
    hPadding: 6 * uiScale

    // El workspace especial (scratchpad, `hl.dsp.workspace.toggle_special("magic")`
    // en binds/init.lua) tiene nombre "special:<nombre>" -- crudo, ese
    // string no entra en un circulo de 20px y se desborda pisando los
    // pills vecinos. Se lo separa del v-for normal y se renderiza aparte,
    // solo mientras existe (scratchpad abierto), con un icono fijo.
    readonly property var special: {
        const list = Hyprland.workspaces.values.filter(w => w.name.indexOf("special:") === 0);
        return list.length > 0 ? list[0] : null;
    }
    readonly property var regular: Hyprland.workspaces.values.filter(w => w.name.indexOf("special:") !== 0);

    Rectangle {
        visible: root.special !== null
        width: 20 * root.uiScale
        height: 20 * root.uiScale
        radius: 8 * root.uiScale
        color: "transparent"
        border.width: 1
        border.color: Colors.accent

        Text {
            anchors.centerIn: parent
            text: "\u{f0d0}" // nf-fa-magic
            color: Colors.accent
            font.family: Colors.fontFamily
            font.pixelSize: root.fontPixelSize - 1
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.special)
                root.special.activate()
        }
    }

    Repeater {
        model: root.regular

        delegate: Rectangle {
            id: wsDelegate
            required property var modelData

            readonly property bool hasContent: wsDelegate.modelData.toplevels.values.length > 0
            // Preferir la ventana marcada "activated" dentro del
            // workspace (la que tendria foco si saltaras a el); si
            // ninguna, la primera de la lista.
            readonly property var focusedToplevel: {
                const wins = wsDelegate.modelData.toplevels.values;
                if (wins.length === 0)
                    return null;
                return wins.find(w => w.activated) || wins[0];
            }
            readonly property string appId: wsDelegate.focusedToplevel && wsDelegate.focusedToplevel.wayland ? wsDelegate.focusedToplevel.wayland.appId : ""
            readonly property bool showDetail: wsDelegate.modelData.focused || wsDelegate.hasContent

            width: 20 * root.uiScale
            height: 20 * root.uiScale
            radius: 8 * root.uiScale
            clip: true
            color: "transparent"
            border.width: wsDelegate.modelData.focused ? 1.5 : 0
            border.color: Colors.accent

            Behavior on border.width {
                NumberAnimation { duration: 120 }
            }

            // vacio y sin foco: solo un punto
            Rectangle {
                visible: !wsDelegate.showDetail
                anchors.centerIn: parent
                width: 6 * root.uiScale
                height: 6 * root.uiScale
                radius: width / 2
                color: Colors.fg
                opacity: 0.45
            }

            // con contenido: icono de la app (la que tenga foco dentro del
            // workspace, o la primera)
            IconImage {
                id: icon
                visible: wsDelegate.showDetail && wsDelegate.appId !== "" && status === Image.Ready
                anchors.centerIn: parent
                implicitSize: 14 * root.uiScale
                source: wsDelegate.appId ? Quickshell.iconPath(wsDelegate.appId) : ""
            }

            // fallback: enfocado pero vacio, o el icono no se pudo resolver
            Text {
                visible: wsDelegate.showDetail && !icon.visible
                anchors.centerIn: parent
                text: wsDelegate.modelData.name
                color: wsDelegate.modelData.focused ? Colors.accent : Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: root.fontPixelSize
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wsDelegate.modelData.activate()
            }
        }
    }
}
