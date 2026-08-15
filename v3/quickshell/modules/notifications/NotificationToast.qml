import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../../theme"
import "../bar"

// Una tarjeta de notificacion "toast" -- usada tanto por el popup
// (NotificationPopupWindow.qml, se autodestruye por su timer) como por
// el historial (NotificationCenter.qml, se queda hasta que la
// descartes). `dismissable` distingue el boton de cierre en cada caso:
// en el popup solo saca el toast de pantalla (sigue en el historial); en
// el historial, cierra la notificacion de verdad (avisa al que la mando).
Rectangle {
    id: root

    property real uiScale: 1.0
    required property var notification
    property bool isPopupContext: true

    readonly property color urgencyColor: notification.urgency === NotificationUrgency.Critical ? Colors.network : (notification.urgency === NotificationUrgency.Low ? Colors.fg : Colors.accent)

    // Icono: mismo criterio que el resto del repo (ver CLAUDE.md) --
    // `hasThemeIcon` ANTES de armar el source, `notification.image` (si
    // vino) tiene prioridad sobre el nombre de icono de la app.
    readonly property string resolvedIconSource: {
        if (notification.image)
            return notification.image;
        const n = notification.appIcon;
        return n && Quickshell.hasThemeIcon(n) ? Quickshell.iconPath(n) : "";
    }

    signal closeRequested

    implicitWidth: 320 * uiScale
    implicitHeight: content.implicitHeight + 20 * uiScale
    radius: 14 * uiScale
    color: Colors.bg
    opacity: 0.97
    border.width: 1
    border.color: Qt.rgba(urgencyColor.r, urgencyColor.g, urgencyColor.b, 0.35)

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12 * root.uiScale
        spacing: 6 * root.uiScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.uiScale

            Rectangle {
                Layout.preferredWidth: 32 * root.uiScale
                Layout.preferredHeight: 32 * root.uiScale
                radius: 10 * root.uiScale
                color: Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.18)

                IconImage {
                    id: appIcon
                    anchors.centerIn: parent
                    implicitSize: 18 * root.uiScale
                    source: root.resolvedIconSource
                    visible: source !== "" && status === Image.Ready
                }

                Text {
                    visible: !appIcon.visible
                    anchors.centerIn: parent
                    text: "\u{f0f3}" // nf-fa-bell
                    color: root.urgencyColor
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.uiScale

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.notification.summary
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 13 * root.uiScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.notification.appName !== ""
                    text: root.notification.appName
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 10 * root.uiScale
                }
            }

            Text {
                text: "\u{f00d}" // nf-fa-times
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Text {
            visible: root.notification.body !== ""
            Layout.fillWidth: true
            text: root.notification.body
            textFormat: Text.StyledText
            color: Colors.fg
            opacity: 0.8
            font.family: Colors.fontFamily
            font.pixelSize: 11 * root.uiScale
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        RowLayout {
            visible: root.notification.actions.length > 0
            Layout.fillWidth: true
            spacing: 8 * root.uiScale

            Repeater {
                model: root.notification.actions

                delegate: ActionChip {
                    required property var modelData
                    uiScale: root.uiScale
                    text: modelData.text
                    variant: "outline"
                    tint: root.urgencyColor
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
