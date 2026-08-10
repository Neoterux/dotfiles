import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../theme"

// Contenido del lanzador nativo: caja de busqueda + grilla de apps
// (Quickshell.DesktopEntries, sin pasar por rofi). Enter lanza el primer
// resultado, Escape cierra.
ColumnLayout {
    id: root
    spacing: 12 * uiScale

    property real uiScale: 1.0

    signal closeRequested

    readonly property var allApps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property var filtered: {
        const q = searchField.text.trim().toLowerCase();
        if (!q)
            return allApps.slice(0, 30);
        return allApps.filter(e => (e.name && e.name.toLowerCase().includes(q)) || (e.genericName && e.genericName.toLowerCase().includes(q))).slice(0, 30);
    }

    function launch(entry) {
        entry.execute();
        searchField.text = "";
        root.closeRequested();
    }

    function launchFirst() {
        if (filtered.length > 0)
            launch(filtered[0]);
    }

    function focusSearch() {
        searchField.forceActiveFocus();
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40 * root.uiScale
        radius: 10 * root.uiScale
        color: Qt.darker(Colors.bg, 0.55)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10 * root.uiScale
            spacing: 10 * root.uiScale

            Text {
                text: "" // nf-fa-search
                color: Colors.fg
                opacity: 0.6
                font.family: Colors.fontFamily
                font.pixelSize: 14 * root.uiScale
            }

            TextInput {
                id: searchField
                Layout.fillWidth: true
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 14 * root.uiScale
                clip: true

                Keys.onReturnPressed: root.launchFirst()
                Keys.onEscapePressed: root.closeRequested()

                Text {
                    visible: searchField.text.length === 0
                    text: "buscar aplicaciones..."
                    color: Colors.fg
                    opacity: 0.4
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                }
            }
        }
    }

    GridLayout {
        Layout.preferredWidth: 5 * 84 * root.uiScale
        columns: 5
        rowSpacing: 12 * root.uiScale
        columnSpacing: 6 * root.uiScale

        Repeater {
            model: root.filtered

            delegate: Item {
                id: appDelegate
                required property var modelData

                Layout.preferredWidth: 80 * root.uiScale
                implicitHeight: col.implicitHeight

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    spacing: 6 * root.uiScale

                    IconImage {
                        Layout.alignment: Qt.AlignHCenter
                        implicitSize: 42 * root.uiScale
                        source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: appDelegate.modelData.name
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 11 * root.uiScale
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }
                }

                // Ver Dashboard.qml: un MouseArea manejado por un Layout
                // (con Layout.* en vez de anchors) es "undefined
                // behavior" en QtQuick y Quickshell lo marca como
                // warning -- por eso va en este Item aparte, con
                // anchors.fill normal.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(appDelegate.modelData)
                }
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        visible: root.filtered.length === 0
        text: "sin resultados"
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 13 * root.uiScale
    }
}
