import QtQuick
import QtQuick.Layouts
import "../../theme"

// Lista de eventos de "Hoy" -- separada de Calendar.qml (antes vivia
// apilada debajo de la grilla, hacia que todo el tab se sintiera muy
// vertical). Se usa como contenido de un DashboardCard propio en
// DashboardTab.qml, al lado de la grilla en vez de debajo.
ColumnLayout {
    id: root
    spacing: 6 * uiScale

    property real uiScale: 1.0
    property var todayEvents: []
    property string statusText: ""

    Text {
        text: "Hoy"
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.bold: true
    }

    Repeater {
        model: root.todayEvents

        delegate: RowLayout {
            id: evtRow
            required property var modelData

            Layout.fillWidth: true
            spacing: 8 * root.uiScale

            Rectangle {
                Layout.preferredWidth: 6 * root.uiScale
                Layout.preferredHeight: 6 * root.uiScale
                radius: width / 2
                color: Colors.accent
            }

            Text {
                visible: !evtRow.modelData.allDay
                text: evtRow.modelData.start.toLocaleTimeString(Qt.locale("es_ES"), "HH:mm")
                color: Colors.fg
                opacity: 0.6
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: evtRow.modelData.title
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                elide: Text.ElideRight
            }
        }
    }

    Text {
        visible: root.todayEvents.length === 0 && root.statusText === ""
        text: "sin eventos hoy"
        color: Colors.fg
        opacity: 0.4
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.italic: true
    }

    Text {
        visible: root.statusText !== ""
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.statusText
        color: root.statusText.indexOf("error") === 0 ? Colors.network : Colors.fg
        opacity: 0.6
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        wrapMode: Text.WordWrap
    }

    Item {
        Layout.fillHeight: true
    }
}
