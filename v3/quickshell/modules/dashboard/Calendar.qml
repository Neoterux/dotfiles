import QtQuick
import QtQuick.Layouts
import "../../theme"

// Calendario simple, mes a mes, sin depender de Qt.labs.calendar (para no
// atarse a un modulo QML opcional). Todo el calculo de dias es JS/Date
// puro. Inspirado en el dashboard de caelestia-dots/shell (el config
// "soramane" del showcase de quickshell.org), pero horizontal y colgando
// de la barra de arriba en vez de un sidebar vertical.
ColumnLayout {
    id: root
    spacing: 12 * uiScale

    property real uiScale: 1.0

    property date viewDate: new Date()
    readonly property date today: new Date()
    property var days: buildDays()

    function shiftMonth(delta) {
        const d = new Date(viewDate);
        d.setDate(1);
        d.setMonth(d.getMonth() + delta);
        viewDate = d;
    }

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Font.Capitalize (font.capitalization) pone en mayuscula CADA
    // palabra ("Domingo 9 De Agosto"), que no es como se escribe en
    // castellano -- esto solo mayuscula la primera letra.
    function cap1(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    function buildDays() {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - first.getDay());

        const list = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            list.push(d);
        }
        return list;
    }

    onViewDateChanged: {
        days = buildDays();
        monthTransition.restart();
    }

    // Cabecera grande: hora + fecha completa, como "hoy" a simple vista
    // antes de entrar al detalle del mes.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: root.today.toLocaleTimeString(Qt.locale("es_ES"), "HH:mm")
            color: Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 32 * root.uiScale
            font.bold: true
        }

        Text {
            text: root.cap1(root.today.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM"))
            color: Colors.fg
            opacity: 0.65
            font.family: Colors.fontFamily
            font.pixelSize: 14 * root.uiScale
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.workspaceBorder
        opacity: 0.4
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: ""
            color: Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 15 * root.uiScale

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shiftMonth(-1)
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.cap1(root.viewDate.toLocaleDateString(Qt.locale("es_ES"), "MMMM yyyy"))
            color: Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 15 * root.uiScale
            font.bold: true
        }

        Text {
            text: ""
            color: Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 15 * root.uiScale

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shiftMonth(1)
            }
        }
    }

    Item {
        id: gridHolder
        Layout.fillWidth: true
        implicitWidth: grid.implicitWidth
        implicitHeight: grid.implicitHeight

        SequentialAnimation {
            id: monthTransition
            NumberAnimation { target: grid; property: "opacity"; to: 0; duration: 70 }
            PropertyAction { target: grid; property: "opacity"; value: 0 }
            NumberAnimation { target: grid; property: "opacity"; to: 1; duration: 110; easing.type: Easing.OutCubic }
        }

        GridLayout {
            id: grid
            columns: 7
            rowSpacing: 8 * root.uiScale
            columnSpacing: 3 * root.uiScale
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: ["D", "L", "M", "M", "J", "V", "S"]
                delegate: Text {
                    required property string modelData
                    Layout.preferredWidth: 32 * root.uiScale
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 13 * root.uiScale
                    font.bold: true
                }
            }

            Repeater {
                model: root.days
                delegate: Rectangle {
                    id: cell
                    required property var modelData

                    readonly property bool inMonth: modelData.getMonth() === root.viewDate.getMonth()
                    readonly property bool isToday: root.isSameDay(modelData, root.today)

                    Layout.preferredWidth: 32 * root.uiScale
                    Layout.preferredHeight: 32 * root.uiScale
                    radius: width / 2
                    color: isToday ? Colors.accent : (cellArea.containsMouse ? Qt.darker(Colors.bg, 0.7) : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.getDate()
                        color: cell.isToday ? Colors.textDark : (cell.inMonth ? Colors.fg : Qt.darker(Colors.fg, 2.2))
                        font.family: Colors.fontFamily
                        font.pixelSize: 13 * root.uiScale
                        font.bold: cell.isToday
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "hoy"
        color: Colors.accent
        font.family: Colors.fontFamily
        font.pixelSize: 12 * root.uiScale
        font.underline: true
        visible: root.viewDate.getMonth() !== root.today.getMonth() || root.viewDate.getFullYear() !== root.today.getFullYear()

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.viewDate = new Date()
        }
    }
}
