import QtQuick
import QtQuick.Layouts
import "../../theme"

// Calendario simple, mes a mes, sin depender de Qt.labs.calendar (para no
// atarse a un modulo QML opcional). Todo el calculo de dias es JS/Date
// puro. Inspirado en el dashboard de caelestia-dots/shell (el config
// "soramane" del showcase de quickshell.org).
//
// Solo la grilla + navegacion de mes -- la hora/fecha grande y la lista
// de eventos de "Hoy" son tarjetas propias en DashboardTab.qml (antes
// vivian ahi tambien, pero apiladas todas en una columna quedaba
// demasiado vertical/angosto). Los datos de eventos externos (ICS/Nylas)
// tampoco viven aca: los junta CalendarEvents.qml una sola vez y se
// pasan `eventDayKeys` como prop, asi Calendar/TodayEvents no duplican
// el fetch.
ColumnLayout {
    id: root
    spacing: 10 * uiScale

    property real uiScale: 1.0
    property var eventDayKeys: ({})

    property date viewDate: new Date()
    readonly property date today: new Date()
    property var days: buildDays()

    function dayKey(d) {
        return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
    }

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

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "" // nf-fa-chevron_left
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
            font.pixelSize: 14 * root.uiScale
            font.bold: true
        }

        Text {
            text: "" // nf-fa-chevron_right
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
            rowSpacing: 6 * root.uiScale
            columnSpacing: 2 * root.uiScale
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: ["D", "L", "M", "M", "J", "V", "S"]
                delegate: Text {
                    required property string modelData
                    Layout.preferredWidth: 28 * root.uiScale
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 12 * root.uiScale
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

                    Layout.preferredWidth: 28 * root.uiScale
                    Layout.preferredHeight: 28 * root.uiScale
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
                        font.pixelSize: 12 * root.uiScale
                        font.bold: cell.isToday
                    }

                    // Punto chico si el dia tiene algun evento externo
                    // (ICS/Nylas) -- no distingue cuantos, solo "hay algo".
                    Rectangle {
                        visible: root.eventDayKeys[root.dayKey(cell.modelData)] === true
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2 * root.uiScale
                        width: 4 * root.uiScale
                        height: 4 * root.uiScale
                        radius: width / 2
                        color: cell.isToday ? Colors.textDark : Colors.accent
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
        font.pixelSize: 11 * root.uiScale
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
