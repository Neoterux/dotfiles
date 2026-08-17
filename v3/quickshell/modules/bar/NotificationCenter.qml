import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../../theme"
import "../drawer"
import "../notifications"

// Icono de campana + historial. Click izq abre/cierra el drawer, click
// der alterna "no molestar" (mismo patron que BluetoothButton: izq
// expande, der es el toggle rapido).
IconButton {
    id: root

    required property var panelWindow
    property bool expanded: false

    readonly property int count: NotificationState.server.trackedNotifications.values.length

    // Tope de alto para la lista del historial, relativo a la pantalla de
    // esta barra y no un numero fijo (el shell corre en monitores de altos
    // distintos, ver shell.qml). Con muchas notificaciones el drawer crecia
    // sin limite hasta pasarse del borde de la pantalla: la mitad de abajo
    // -- incluido "limpiar todo" -- quedaba fuera de alcance.
    readonly property real listMaxHeight: (root.panelWindow && root.panelWindow.screen ? root.panelWindow.screen.height : 1080) * 0.6

    icon: NotificationState.doNotDisturb ? "\u{f1f6}" : "\u{f0f3}" // nf-fa-bell-slash / nf-fa-bell
    active: root.count > 0
    fontScale: 1.05

    // Mismo patron que TrayItem: el click que cierra el drawer por
    // click-afuera tambien llega a este icono, y sin la ventana de gracia
    // el toggle de abajo lo reabriria en el mismo click.
    property double lastDismiss: 0

    function justDismissed(): bool {
        return Date.now() - root.lastDismiss < 200;
    }

    onLeftClicked: {
        if (root.justDismissed())
            return;
        root.expanded = !root.expanded;
    }
    onRightClicked: NotificationState.doNotDisturb = !NotificationState.doNotDisturb

    // Numerito con la cantidad, esquina superior derecha del icono --
    // mismo lugar/tamaño que un badge de notificaciones tipico.
    Rectangle {
        visible: root.count > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 1 * root.uiScale
        anchors.rightMargin: 1 * root.uiScale
        width: Math.max(12 * root.uiScale, badgeText.implicitWidth + 4 * root.uiScale)
        height: 12 * root.uiScale
        radius: height / 2
        color: Colors.network

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.count > 9 ? "9+" : root.count
            color: Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 8 * root.uiScale
            font.bold: true
        }
    }

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded
        // El drawer se abre por click (no por hover), asi que el grab de
        // entrada no se come nada: cerrarlo clickeando en cualquier lado
        // es la unica salida cuando la lista es larga y tapa media
        // pantalla.
        dismissOnClickOutside: true
        onDismissed: {
            root.lastDismiss = Date.now();
            root.expanded = false;
        }

        ColumnLayout {
            // `width` explicito, no `Layout.preferredWidth` -- el padre
            // directo (`inner` en Drawer.qml) es un Item plano, no un
            // Layout, ese attached property no hace nada ahi (ver
            // NetworkStatus.qml/BluetoothButton.qml, mismo bug ya
            // encontrado y corregido antes).
            width: 340 * root.uiScale
            spacing: 10 * root.uiScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.uiScale

                Text {
                    Layout.fillWidth: true
                    text: "Notificaciones"
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                    font.bold: true
                }

                // Switch de "no molestar" -- mismo patron que el de
                // wifi/bluetooth (Rectangle a mano, sin QtQuick.Controls).
                Item {
                    id: dndToggle
                    Layout.preferredWidth: 32 * root.uiScale
                    Layout.preferredHeight: 17 * root.uiScale

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: NotificationState.doNotDisturb ? Colors.accent : Qt.darker(Colors.bg, 0.5)

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                    }

                    Rectangle {
                        width: 13 * root.uiScale
                        height: 13 * root.uiScale
                        radius: width / 2
                        y: 2 * root.uiScale
                        color: Colors.fg
                        x: NotificationState.doNotDisturb ? parent.width - width - 2 * root.uiScale : 2 * root.uiScale

                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationState.doNotDisturb = !NotificationState.doNotDisturb
                    }
                }
            }

            Text {
                visible: NotificationState.doNotDisturb
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "No molestar activado -- las notificaciones nuevas no muestran toast (siguen quedando acá)"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 10 * root.uiScale
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.workspaceBorder
                opacity: 0.25
            }

            // La lista va adentro de un Flickable con tope de alto: el
            // encabezado y "limpiar todo" quedan siempre a la vista pase lo
            // que pase con la cantidad de notificaciones (mismo arreglo que
            // los menus largos de bandeja, ver tray/TrayItem.qml).
            Item {
                visible: root.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(list.implicitHeight, root.listMaxHeight)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: list
                        width: flick.width
                        spacing: 6 * root.uiScale

                        Repeater {
                            model: NotificationState.server.trackedNotifications.values

                            delegate: NotificationToast {
                                required property var modelData
                                Layout.fillWidth: true
                                uiScale: root.uiScale
                                notification: modelData
                                // Historial, no toast: sin animacion de
                                // entrada (ver NotificationToast.qml).
                                isPopupContext: false
                                // Solo `dismiss()`: destruye la
                                // notificacion, cualquier cosa que se le
                                // toque despues (p.ej. `tracked`) ya es
                                // sobre un objeto muerto.
                                onCloseRequested: modelData.dismiss()
                            }
                        }
                    }
                }

                // Indicador de scroll -- afuera del Flickable, si no seria
                // hijo del contentItem y scrollearia junto con la lista.
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

            Text {
                visible: root.count === 0
                Layout.fillWidth: true
                text: "sin notificaciones"
                color: Colors.fg
                opacity: 0.4
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                font.italic: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                visible: root.count > 0
                Layout.alignment: Qt.AlignHCenter
                text: "limpiar todo"
                color: Colors.network
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.underline: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationState.clearAll()
                }
            }
        }
    }
}
