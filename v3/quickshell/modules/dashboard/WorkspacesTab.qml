import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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

            // Tinte de acento en el workspace enfocado -- mismo criterio
            // visual que MetricCard (Performance) y los drawers de red/
            // bluetooth, en vez del gris plano que tenia antes.
            Layout.preferredWidth: 200 * root.uiScale
            Layout.fillHeight: true
            Layout.minimumHeight: content.implicitHeight + 20 * root.uiScale
            radius: 14 * root.uiScale
            color: wsCard.modelData.focused ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : Qt.darker(Colors.bg, 0.6)
            border.width: wsCard.modelData.focused ? 1 : 0
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.35)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wsCard.modelData.activate()
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 12 * root.uiScale
                spacing: 8 * root.uiScale

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
                        color: wsCard.modelData.focused ? Colors.accent : Colors.fg
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

                    delegate: RowLayout {
                        id: winRow
                        required property var modelData
                        // XWayland toplevels no siempre traen `.wayland`
                        // poblado -- mismo guard que ya usa Workspaces.qml
                        // (bar) para el icono de cada pill.
                        readonly property string appId: winRow.modelData.wayland ? winRow.modelData.wayland.appId : ""

                        Layout.fillWidth: true
                        spacing: 6 * root.uiScale

                        IconImage {
                            id: winIcon
                            Layout.preferredWidth: 14 * root.uiScale
                            Layout.preferredHeight: 14 * root.uiScale
                            source: winRow.appId ? Quickshell.iconPath(winRow.appId) : ""
                            visible: winRow.appId !== "" && status === Image.Ready
                        }

                        Text {
                            visible: !winIcon.visible
                            text: "•"
                            color: Colors.fg
                            opacity: 0.6
                            font.family: Colors.fontFamily
                            font.pixelSize: 12 * root.uiScale
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: winRow.modelData.title || "(sin titulo)"
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
}
