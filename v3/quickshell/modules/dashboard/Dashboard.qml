import QtQuick
import QtQuick.Layouts
import "../../theme"

// Contenedor con pestañas (Dashboard / Media / Performance / Workspaces),
// inspirado en el dashboard de caelestia-dots/shell (config "soramane" del
// showcase de quickshell.org) pero colgando horizontal de la barra de
// arriba en vez de ser un sidebar vertical.
ColumnLayout {
    id: root
    spacing: 14 * uiScale

    property real uiScale: 1.0

    readonly property var tabs: [
        { name: "Dashboard", icon: "" },
        { name: "Media", icon: "" },
        { name: "Performance", icon: "" },
        { name: "Workspaces", icon: "" },
        { name: "Servers", icon: "" },
    ]
    property int currentTab: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: 6 * root.uiScale

        Repeater {
            model: root.tabs

            delegate: Item {
                id: tabDelegate
                required property var modelData
                required property int index

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: col.implicitWidth
                implicitHeight: col.implicitHeight

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    spacing: 6 * root.uiScale

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8 * root.uiScale

                        Text {
                            text: tabDelegate.modelData.icon
                            color: root.currentTab === tabDelegate.index ? Colors.accent : Colors.fg
                            opacity: root.currentTab === tabDelegate.index ? 1 : 0.55
                            font.family: Colors.fontFamily
                            font.pixelSize: 15 * root.uiScale
                        }

                        Text {
                            text: tabDelegate.modelData.name
                            color: root.currentTab === tabDelegate.index ? Colors.accent : Colors.fg
                            opacity: root.currentTab === tabDelegate.index ? 1 : 0.55
                            font.family: Colors.fontFamily
                            font.pixelSize: 13 * root.uiScale
                            font.bold: root.currentTab === tabDelegate.index
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 2 * root.uiScale
                        radius: 1
                        color: Colors.accent
                        opacity: root.currentTab === tabDelegate.index ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }
                    }
                }

                // Cubre TODO el delegate (icono + label + subrayado), no
                // solo una franja aparte debajo del texto -- ese era el
                // bug: se podia ver la tab pero clickearla no hacia nada
                // porque el area clickeable estaba mas abajo.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = tabDelegate.index
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.workspaceBorder
        opacity: 0.3
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
        implicitWidth: pageLoader.item ? pageLoader.item.implicitWidth : 0

        Loader {
            id: pageLoader
            sourceComponent: [dashboardPage, mediaPage, performancePage, workspacesPage, serversPage][root.currentTab]

            opacity: 0
            Component.onCompleted: opacity = 1
            onLoaded: {
                opacity = 0;
                fadeIn.restart();
            }

            NumberAnimation {
                id: fadeIn
                target: pageLoader
                property: "opacity"
                to: 1
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    Component {
        id: dashboardPage
        DashboardTab { uiScale: root.uiScale }
    }

    Component {
        id: mediaPage
        MediaTab { uiScale: root.uiScale }
    }

    Component {
        id: performancePage
        PerformanceTab { uiScale: root.uiScale }
    }

    Component {
        id: workspacesPage
        WorkspacesTab { uiScale: root.uiScale }
    }

    Component {
        id: serversPage
        ServersTab { uiScale: root.uiScale }
    }
}
