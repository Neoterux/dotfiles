import QtQuick
import Quickshell
import "../../theme"

// Ventana propia para el launcher (PanelWindow, no PopupWindow): el
// buscador necesita foco de teclado real, y un PopupWindow (xdg-popup)
// con `grabFocus: true` no renderiza nada -- falla en silencio. Un
// PanelWindow con `focusable` es el mecanismo pensado para esto
// (lockscreens, launchers) y anda bien.
PanelWindow {
    id: root

    property bool shown: false
    property real uiScale: 1.0
    required property var panelScreen

    screen: panelScreen
    // Igual que Drawer.qml: `visible` real se sostiene un rato mas mientras
    // corre la animacion de cierre, para que no desaparezca de un tiron.
    visible: shown || closeAnim.running
    focusable: shown

    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.round(8 * uiScale)
        left: Math.round(10 * uiScale)
    }

    implicitWidth: 480 * uiScale
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    signal dismissed

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: launcherContent.implicitHeight + 40 * root.uiScale
        radius: 18 * root.uiScale
        color: Colors.bgTranslucent
        transformOrigin: Item.Top
        opacity: 0
        scale: 0.94

        AppLauncher {
            id: launcherContent
            uiScale: root.uiScale
            anchors.fill: parent
            anchors.margins: 20 * root.uiScale
            onCloseRequested: root.dismissed()
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 0.95; duration: 170; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "scale"; to: 0.94; duration: 130; easing.type: Easing.InCubic }
        }
    }

    onShownChanged: {
        if (shown) {
            closeAnim.stop();
            openAnim.restart();
            launcherContent.focusSearch();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }
}
