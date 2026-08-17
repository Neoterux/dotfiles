import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"

// Lista de entradas de un menu de bandeja (DBusMenu), dibujada en QML.
//
// El camino "obvio" -- `trayItem.display(window, x, y)` -- NO sirve en
// este shell: abre un menu de PLATAFORMA (QtWidgets) y quickshell aborta
// con "Cannot display PlatformMenuEntry as quickshell was not started in
// QApplication mode", que solo se arregla agregando `//@ pragma
// UseQApplication` al shell.qml. Eso ademas dibujaria el menu con el
// estilo del sistema, no con el de la barra. QsMenuOpener expone las
// mismas entradas como modelo y las pintamos nosotros.
//
// Se instancia a si misma via Loader (no directo: QML rechaza la
// recursion de tipos) para los submenus -- una QsMenuEntry con
// `hasChildren` es tambien un handle de menu valido.
ColumnLayout {
    id: root

    property real uiScale: 1.0
    // Handle del menu: `trayItem.menu` en el nivel de arriba, o la propia
    // entrada padre cuando es un submenu.
    property var menuHandle: null

    signal entryTriggered

    spacing: 2 * uiScale

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    Text {
        // Un menu vacio no es raro: hay apps que recien arman el DBusMenu
        // cuando se lo piden, asi que la primera apertura puede llegar sin
        // entradas todavia.
        visible: opener.children.values.length === 0
        Layout.fillWidth: true
        text: "sin opciones"
        color: Colors.fg
        opacity: 0.45
        font.family: Colors.fontFamily
        font.pixelSize: 12 * root.uiScale
        font.italic: true
    }

    Repeater {
        model: opener.children.values

        delegate: ColumnLayout {
            id: entry
            required property var modelData

            property bool expanded: false
            readonly property bool isCheckable: entry.modelData.buttonType !== QsMenuButtonType.None
            readonly property bool isChecked: entry.modelData.checkState === Qt.Checked

            Layout.fillWidth: true
            spacing: 2 * root.uiScale

            Rectangle {
                visible: entry.modelData.isSeparator
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 3 * root.uiScale
                Layout.bottomMargin: 3 * root.uiScale
                color: Colors.fg
                opacity: 0.15
            }

            // MouseArea + contenido envueltos en un Item que es el que
            // lleva los Layout.* (ver CLAUDE.md: un MouseArea suelto como
            // hijo directo de un Layout desalinea el area de click).
            Item {
                id: row
                visible: !entry.modelData.isSeparator
                Layout.fillWidth: true
                implicitHeight: rowLayout.implicitHeight + 9 * root.uiScale

                Rectangle {
                    anchors.fill: parent
                    radius: 8 * root.uiScale
                    color: hover.containsMouse ? Qt.lighter(Colors.bg, 2.2) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }
                }

                RowLayout {
                    id: rowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 9 * root.uiScale
                    anchors.rightMargin: 9 * root.uiScale
                    spacing: 8 * root.uiScale

                    Text {
                        visible: entry.isCheckable
                        text: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? (entry.isChecked ? "\u{f192}" : "\u{f10c}") // nf-fa-dot_circle_o / nf-fa-circle_o
                                                                                          : (entry.isChecked ? "\u{f046}" : "\u{f096}") // nf-fa-check_square_o / nf-fa-square_o
                        color: entry.isChecked ? Colors.accent : Colors.fg
                        opacity: entry.isChecked ? 1 : 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 12 * root.uiScale
                    }

                    IconImage {
                        visible: TrayIcons.usable(entry.modelData.icon)
                        implicitSize: 14 * root.uiScale
                        source: TrayIcons.usable(entry.modelData.icon) ? entry.modelData.icon : ""
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: entry.modelData.text
                        color: Colors.fg
                        opacity: entry.modelData.enabled ? 1 : 0.4
                        font.family: Colors.fontFamily
                        font.pixelSize: 12 * root.uiScale
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: entry.modelData.hasChildren
                        text: "\u{f054}" // nf-fa-chevron_right
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 9 * root.uiScale
                        rotation: entry.expanded ? 90 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: entry.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            entry.expanded = !entry.expanded;
                            return;
                        }
                        entry.modelData.triggered();
                        root.entryTriggered();
                    }
                }
            }

            // Submenu: el Loader corta la recursion de tipos que QML no
            // acepta si el archivo se instancia a si mismo directo.
            Loader {
                active: entry.modelData.hasChildren && entry.expanded
                visible: active
                Layout.fillWidth: true
                Layout.leftMargin: 12 * root.uiScale
                source: "TrayMenuList.qml"

                onLoaded: {
                    item.uiScale = root.uiScale;
                    item.menuHandle = entry.modelData;
                    item.entryTriggered.connect(root.entryTriggered);
                }
            }
        }
    }
}
