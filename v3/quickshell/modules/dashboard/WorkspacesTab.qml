import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../theme"

// Pestaña "Workspaces": resumen de que hay abierto en cada workspace.
GridLayout {
    id: root
    columns: 2
    columnSpacing: 16 * uiScale
    rowSpacing: 12 * uiScale

    property real uiScale: 1.0

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: wsCard
            required property var modelData

            Layout.preferredWidth: 200 * root.uiScale
            Layout.fillHeight: true
            Layout.minimumHeight: content.implicitHeight + 20 * root.uiScale
            radius: 12 * root.uiScale
            color: wsCard.modelData.focused ? Qt.lighter(Colors.bg, 1.8) : Qt.darker(Colors.bg, 0.6)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wsCard.modelData.activate()
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 10 * root.uiScale
                spacing: 6 * root.uiScale

                RowLayout {
                    spacing: 8 * root.uiScale

                    Rectangle {
                        Layout.preferredWidth: 9 * root.uiScale
                        Layout.preferredHeight: 9 * root.uiScale
                        radius: width / 2
                        color: wsCard.modelData.focused ? Colors.accent : Colors.fg
                        opacity: wsCard.modelData.focused ? 1 : 0.4
                    }

                    Text {
                        text: "Workspace " + wsCard.modelData.name
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 13 * root.uiScale
                        font.bold: true
                    }
                }

                Text {
                    visible: wsCard.modelData.toplevels.values.length === 0
                    text: "vacio"
                    color: Colors.fg
                    opacity: 0.4
                    font.family: Colors.fontFamily
                    font.pixelSize: 12 * root.uiScale
                    font.italic: true
                }

                Repeater {
                    model: wsCard.modelData.toplevels.values

                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "• " + (modelData.title || "(sin titulo)")
                        color: Colors.fg
                        opacity: 0.75
                        font.family: Colors.fontFamily
                        font.pixelSize: 12 * root.uiScale
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
