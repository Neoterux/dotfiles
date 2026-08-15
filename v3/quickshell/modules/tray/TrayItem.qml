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
    //
    // OJO: `img.status === Image.Ready` NO alcanza para detectar esto --
    // confirmado en vivo que cuando el nombre de icono no existe en el
    // tema, el proveedor `image://icon/` de todos modos "carga" (status
    // Ready) el placeholder "imagen rota" del tema (cuadriculado
    // magenta/negro) en vez de fallar. Por eso se valida el nombre real
    // con `hasThemeIcon` ANTES de armar el source, en vez de confiar en
    // el status despues de intentar cargarlo.
    icon: root.iconUsable && img.status === Image.Ready ? "" : "" // nf-fa-circle_o
    implicitWidth: 26 * uiScale
    implicitHeight: 26 * uiScale

    // `trayItem.icon` ya es una URL lista para usar (`image://icon/...` o
    // `image://qsimage/...` cuando la app manda el pixmap por DBus en vez
    // de un nombre de tema) -- pasarla por Quickshell.iconPath() devuelve
    // vacio y el icono no se dibuja. Si es un lookup por nombre de tema
    // (`image://icon/`), se valida ese nombre con `hasThemeIcon` primero;
    // si viene como pixmap crudo (`image://qsimage/`) no hay nombre que
    // validar, se usa directo.
    readonly property string iconUrl: root.trayItem ? root.trayItem.icon : ""
    readonly property string themeIconName: root.iconUrl.indexOf("image://icon/") === 0 ? root.iconUrl.slice("image://icon/".length).split("?")[0] : ""
    readonly property bool iconUsable: root.iconUrl !== "" && (root.themeIconName === "" || Quickshell.hasThemeIcon(root.themeIconName))

    IconImage {
        id: img
        anchors.centerIn: parent
        implicitSize: 15 * root.uiScale
        source: root.iconUsable ? root.iconUrl : ""
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
