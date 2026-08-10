import QtQuick
import QtQuick.Layouts
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

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        ColumnLayout {
            spacing: 10 * root.uiScale

            Text {
                text: root.btEnabled ? "Bluetooth activado" : "Bluetooth desactivado"
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
                font.bold: true
            }

            Repeater {
                model: root.adapter ? root.adapter.devices.values : []
                delegate: RowLayout {
                    id: devRow
                    required property var modelData
                    spacing: 8 * root.uiScale

                    Rectangle {
                        Layout.preferredWidth: 7 * root.uiScale
                        Layout.preferredHeight: 7 * root.uiScale
                        radius: width / 2
                        color: devRow.modelData.connected ? Colors.accent : Qt.darker(Colors.fg, 2)
                    }

                    Text {
                        text: devRow.modelData.name
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 12 * root.uiScale
                    }
                }
            }

            Text {
                visible: !root.adapter || root.adapter.devices.values.length === 0
                text: "sin dispositivos emparejados"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
            }
        }
    }
}
