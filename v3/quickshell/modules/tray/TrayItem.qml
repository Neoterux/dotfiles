import QtQuick
import Quickshell
import Quickshell.Widgets
import "../bar"
import "../../theme"

// Un icono de la bandeja del sistema (Discord, Steam, lo que sea que
// hable el protocolo StatusNotifierItem/KDE tray). Click izq activa el
// item (icon click normal), click der abre su menu si tiene uno.
IconButton {
    id: root

    required property var trayItem
    required property var panelWindow

    icon: ""
    implicitWidth: 26 * uiScale
    implicitHeight: 26 * uiScale

    IconImage {
        anchors.centerIn: parent
        implicitSize: 15 * root.uiScale
        source: root.trayItem ? Quickshell.iconPath(root.trayItem.icon, true) : ""
    }

    onLeftClicked: {
        if (root.trayItem)
            root.trayItem.activate();
    }

    onRightClicked: {
        if (root.trayItem && root.trayItem.hasMenu)
            root.trayItem.display(root.panelWindow, 0, root.height);
    }
}
