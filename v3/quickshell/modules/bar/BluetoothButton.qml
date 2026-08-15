import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Bluetooth
import "../../theme"
import "../drawer"

// Icono de bluetooth -- solo se muestra si hay un adaptador disponible.
// Click: toggle on/off. El popup lista los dispositivos conectados.
IconButton {
    id: root

    required property var panelWindow
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool btEnabled: available && adapter.enabled

    visible: available
    // Un solo icono para ambos estados -- el color (`active`) ya
    // distingue encendido/apagado, no hace falta un segundo glifo.
    icon: "" // nf-fa-bluetooth_b
    active: btEnabled
    fontScale: 1.15

    onLeftClicked: root.expanded = !root.expanded
    onRightClicked: {
        if (root.adapter)
            root.adapter.enabled = !root.adapter.enabled;
    }

    property bool expanded: false

    // Solo escanear activamente (visible a otros y buscando dispositivos
    // nuevos) mientras el drawer esta abierto -- mismo criterio que el
    // escaneo de wifi en NetworkStatus.qml, no tiene sentido gastar radio
    // si nadie esta mirando la lista.
    onExpandedChanged: {
        if (root.adapter) {
            root.adapter.discovering = root.expanded && root.btEnabled;
            root.adapter.discoverable = root.expanded && root.btEnabled;
        }
    }

    readonly property var connectedDevices: root.adapter ? root.adapter.devices.values.filter(d => d.connected) : []
    readonly property var pairedDevices: root.adapter ? root.adapter.devices.values.filter(d => !d.connected && d.paired) : []
    readonly property var availableDevices: root.adapter ? root.adapter.devices.values.filter(d => !d.connected && !d.paired) : []

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        ColumnLayout {
            // `width` explicito, no `Layout.preferredWidth`: el padre
            // directo (`inner` en Drawer.qml) es un Item plano, no un
            // Layout, asi que ese attached property no hace nada -- sin
            // esto, cada fila queda con un ancho distinto segun su propio
            // contenido y los ActionChip terminan aplastados/recortados.
            width: 320 * root.uiScale
            spacing: 12 * root.uiScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.uiScale

                Text {
                    Layout.fillWidth: true
                    text: root.adapter ? root.adapter.name : "Bluetooth"
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Switch on/off (mismo patron que el de wifi en NetworkStatus.qml).
                Item {
                    id: btToggle
                    Layout.preferredWidth: 32 * root.uiScale
                    Layout.preferredHeight: 17 * root.uiScale
                    enabled: root.available

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.btEnabled ? Colors.accent : Qt.darker(Colors.bg, 0.5)
                        opacity: btToggle.enabled ? 1 : 0.4

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
                        opacity: btToggle.enabled ? 1 : 0.4
                        x: root.btEnabled ? parent.width - width - 2 * root.uiScale : 2 * root.uiScale

                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: btToggle.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.adapter.enabled = !root.adapter.enabled
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.btEnabled
                spacing: 14 * root.uiScale

                Text {
                    text: (root.adapter && root.adapter.discovering) ? "buscando dispositivos..." : "visible y detectable"
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 10 * root.uiScale
                    font.italic: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.btEnabled
                height: 1
                color: Colors.workspaceBorder
                opacity: 0.25
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.btEnabled
                spacing: 10 * root.uiScale

                BluetoothDeviceSection {
                    uiScale: root.uiScale
                    title: "Conectados"
                    devices: root.connectedDevices
                }

                BluetoothDeviceSection {
                    uiScale: root.uiScale
                    title: "Emparejados"
                    devices: root.pairedDevices
                }

                BluetoothDeviceSection {
                    uiScale: root.uiScale
                    title: "Disponibles"
                    devices: root.availableDevices
                }

                Text {
                    visible: root.adapter && root.adapter.devices.values.length === 0
                    text: root.adapter && root.adapter.discovering ? "buscando..." : "sin dispositivos"
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 12 * root.uiScale
                    font.italic: true
                }
            }

            Text {
                visible: !root.btEnabled
                text: "Bluetooth desactivado"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                font.italic: true
            }
        }
    }
}
