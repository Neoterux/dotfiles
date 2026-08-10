import QtQuick
import Quickshell.Hyprland
import "../../theme"

// Equivalente a "hyprland/workspaces" de waybar, pero reactivo via la IPC
// nativa de Quickshell (Hyprland.workspaces) en vez de leer el socket a mano.
Pill {
    id: root
    bg: Colors.bgTranslucent
    fg: Colors.fg
    hPadding: 6 * uiScale

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: wsDelegate
            required property var modelData
            // Los workspaces especiales (scratchpad, `hl.dsp.workspace.toggle_special("magic")`
            // en binds/init.lua) tienen nombre "special:<nombre>" -- crudo,
            // ese string no entra en un circulo de 20px y se desborda
            // pisando los pills vecinos. Se les pone un icono fijo en vez
            // del nombre, y `clip: true` como red de seguridad por si
            // aparece otro nombre largo en el futuro.
            readonly property bool isSpecial: wsDelegate.modelData.name.indexOf("special:") === 0

            width: 20 * root.uiScale
            height: 20 * root.uiScale
            radius: 8 * root.uiScale
            clip: true
            color: modelData.focused ? Colors.workspaceActiveBg : "transparent"
            border.width: modelData.focused ? 0 : 1
            border.color: wsDelegate.isSpecial ? Colors.accent : Colors.workspaceBorder

            Text {
                anchors.centerIn: parent
                text: wsDelegate.isSpecial ? "\u{f0d0}" : wsDelegate.modelData.name // nf-fa-magic
                color: wsDelegate.modelData.focused ? Colors.workspaceActiveFg : (wsDelegate.isSpecial ? Colors.accent : Colors.fg)
                font.family: Colors.fontFamily
                font.pixelSize: wsDelegate.isSpecial ? root.fontPixelSize - 1 : root.fontPixelSize
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
