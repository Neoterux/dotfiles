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

    // Fallback visible solo si el icono del item no carga (algunas apps
    // publican un nombre de icono que no existe en el tema): sin esto el
    // item queda como un hueco clickeable invisible.
    icon: img.status === Image.Ready ? "" : "" // nf-fa-circle_o
    implicitWidth: 26 * uiScale
    implicitHeight: 26 * uiScale

    // `trayItem.icon` ya es una URL lista para usar (`image://icon/...` o
    // `image://qsimage/...` cuando la app manda el pixmap por DBus en vez
    // de un nombre de tema) -- pasarla por Quickshell.iconPath() devuelve
    // vacio y el icono no se dibuja.
    IconImage {
        id: img
        anchors.centerIn: parent
        implicitSize: 15 * root.uiScale
        source: root.trayItem ? root.trayItem.icon : ""
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
