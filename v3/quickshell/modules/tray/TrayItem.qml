import QtQuick
import Quickshell
import Quickshell.Widgets
import "../bar"
import "../drawer"
import "../../theme"

// Un icono de la bandeja del sistema (Discord, Steam, lo que sea que
// hable el protocolo StatusNotifierItem/KDE tray). Click izq activa el
// item (icon click normal), click der abre su menu si tiene uno.
IconButton {
    id: root

    required property var trayItem
    required property var panelWindow

    property bool menuOpen: false

    readonly property real menuWidth: 210 * uiScale
    // Relativo a la pantalla de esta barra, no un numero fijo: el shell
    // corre en monitores de altos distintos (ver shell.qml).
    readonly property real menuMaxHeight: (root.panelWindow && root.panelWindow.screen ? root.panelWindow.screen.height : 1080) * 0.55

    // Fallback visible solo si el icono del item no carga (algunas apps
    // publican un nombre de icono que no existe en ningun lado): sin esto
    // el item queda como un hueco clickeable invisible. El status del
    // Image NO sirve para detectarlo -- ver TrayIcons.qml, que es quien
    // sabe cuando una URL de icono es realmente usable.
    icon: root.iconUsable ? "" : "" // nf-fa-circle_o

    // `trayItem.icon` ya es una URL lista para usar -- pasarla por
    // Quickshell.iconPath() devuelve vacio y el icono no se dibuja.
    readonly property string iconUrl: root.trayItem ? root.trayItem.icon : ""
    readonly property bool iconUsable: TrayIcons.usable(root.iconUrl)

    IconImage {
        anchors.centerIn: parent
        implicitSize: 15 * root.uiScale
        source: root.iconUsable ? root.iconUrl : ""
    }

    // Cuando el click que cierra el menu cae justo sobre este mismo icono,
    // no hay que hacer nada mas con el: sin esta ventana de gracia el
    // toggle de abajo lo reabriria en el mismo click (menu "pegado") y el
    // click izquierdo activaria la app de yapa.
    property double lastDismiss: 0

    // Funcion y no `readonly property`: un binding con Date.now() adentro
    // se evalua una sola vez y queda cacheado (no hay nada reactivo que lo
    // invalide al pasar los 200ms), asi que quedaria en true para siempre
    // despues del primer cierre.
    function justDismissed(): bool {
        return Date.now() - root.lastDismiss < 200;
    }

    onLeftClicked: {
        if (root.justDismissed())
            return;
        root.menuOpen = false;
        if (root.trayItem)
            root.trayItem.activate();
    }

    onRightClicked: {
        if (root.justDismissed())
            return;
        if (root.trayItem && root.trayItem.hasMenu)
            root.menuOpen = !root.menuOpen;
    }

    Drawer {
        id: menuDrawer
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.menuOpen
        dismissOnClickOutside: true
        onDismissed: {
            root.lastDismiss = Date.now();
            root.menuOpen = false;
        }

        // El menu se arma recien al abrirlo: QsMenuOpener mantiene abierto
        // el DBusMenu de la app mientras exista, y no tiene sentido tener
        // uno vivo por cada item de la bandeja todo el tiempo. Sigue
        // cargado durante la animacion de cierre (visible, no shown) para
        // que no se vacie de golpe.
        Loader {
            active: menuDrawer.visible
            width: root.menuWidth

            // Los menus de bandeja pueden ser largos de verdad (el de
            // remmina lista todas las conexiones guardadas: se pasaba del
            // borde inferior de la pantalla y las ultimas entradas
            // quedaban fuera de alcance). De ahi el tope + scroll.
            sourceComponent: Item {
                implicitWidth: root.menuWidth
                implicitHeight: Math.min(list.implicitHeight, root.menuMaxHeight)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    TrayMenuList {
                        id: list
                        width: flick.width
                        uiScale: root.uiScale
                        menuHandle: root.trayItem ? root.trayItem.menu : null
                        onEntryTriggered: root.menuOpen = false
                    }
                }

                // Indicador de scroll: sin esto no hay ninguna pista de
                // que el menu sigue mas abajo. Va afuera del Flickable --
                // adentro seria hijo del contentItem y scrollearia junto
                // con las entradas.
                Rectangle {
                    visible: flick.interactive
                    width: 3 * root.uiScale
                    height: Math.max(20 * root.uiScale, flick.height * (flick.height / flick.contentHeight))
                    x: parent.width - width
                    y: flick.contentHeight > 0 ? (flick.contentY / flick.contentHeight) * flick.height : 0
                    radius: width / 2
                    color: Colors.fg
                    opacity: 0.25
                }
            }
        }
    }
}
