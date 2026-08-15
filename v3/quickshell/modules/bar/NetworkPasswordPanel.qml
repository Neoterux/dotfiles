import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../../theme"

// Ventana propia (PanelWindow, no Drawer/PopupWindow) para pedir la
// contraseña de una red wifi asegurada: necesita foco de teclado real, y
// un PopupWindow con `grabFocus: true` no renderiza nada -- mismo problema
// que el buscador del launcher, misma solucion (ver LauncherPanel.qml).
PanelWindow {
    id: root

    property bool shown: false
    property real uiScale: 1.0
    required property var panelScreen
    // La WifiNetwork a la que se esta por conectar. La deja puesta
    // NetworkStatus.qml al abrir; `Connections` de abajo la trackea para
    // mostrar el error y para cerrar solo si la conexion realmente prendio.
    property var network: null
    property string errorText: ""

    function openFor(net) {
        root.network = net;
        root.errorText = "";
        passwordField.text = "";
        root.shown = true;
    }

    function dismiss() {
        root.shown = false;
    }

    function submit() {
        if (root.network)
            root.network.connectWithPsk(passwordField.text);
    }

    screen: panelScreen
    visible: shown || closeAnim.running
    focusable: shown

    anchors {
        top: true
        right: true
    }
    margins {
        top: Math.round(8 * uiScale)
        right: Math.round(10 * uiScale)
    }

    implicitWidth: 300 * uiScale
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    Connections {
        target: root.network
        function onConnectionFailed(reason) {
            root.errorText = ConnectionFailReason.toString(reason);
        }
        function onConnectedChanged() {
            if (root.network && root.network.connected)
                root.dismiss();
        }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 32 * root.uiScale
        radius: 16 * root.uiScale
        color: Colors.bgTranslucent
        transformOrigin: Item.Top
        opacity: 0
        scale: 0.94

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 16 * root.uiScale
            spacing: 10 * root.uiScale

            Text {
                Layout.fillWidth: true
                text: root.network ? root.network.name : ""
                color: Colors.fg
                font.family: Colors.fontFamily
                font.bold: true
                font.pixelSize: 13 * root.uiScale
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34 * root.uiScale
                radius: 8 * root.uiScale
                color: Qt.darker(Colors.bg, 0.55)
                border.width: passwordField.activeFocus ? 1 : 0
                border.color: Colors.accent

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 8 * root.uiScale
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 13 * root.uiScale
                    echoMode: TextInput.Password
                    clip: true

                    Keys.onReturnPressed: root.submit()
                    Keys.onEscapePressed: root.dismiss()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.errorText !== ""
                text: root.errorText
                color: Colors.network
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 14 * root.uiScale

                Text {
                    text: "Cancelar"
                    color: Colors.fg
                    opacity: 0.6
                    font.family: Colors.fontFamily
                    font.pixelSize: 12 * root.uiScale

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }

                Text {
                    text: "Conectar"
                    color: Colors.accent
                    font.family: Colors.fontFamily
                    font.bold: true
                    font.pixelSize: 12 * root.uiScale

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 0.97; duration: 170; easing.type: Easing.OutCubic }
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
            passwordField.forceActiveFocus();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }
}
