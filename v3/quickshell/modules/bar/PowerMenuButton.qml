import QtQuick
import QtQuick.Layouts
import "../../theme"

// Un boton del PowerMenu. Si `needsConfirm` es true, el primer click solo
// "arma" el boton (emite `arm`) y hay que clickearlo de nuevo para que
// dispare `activated` -- para no reiniciar/apagar por un click accidental.
ColumnLayout {
    id: root

    property real uiScale: 1.0
    property string icon: ""
    property string label: ""
    property bool needsConfirm: false
    property bool armed: false

    signal arm
    signal activated

    spacing: 6 * uiScale

    Rectangle {
        Layout.preferredWidth: 54 * root.uiScale
        Layout.preferredHeight: 54 * root.uiScale
        Layout.alignment: Qt.AlignHCenter
        radius: 14 * root.uiScale
        color: root.armed ? Colors.accent : (hoverArea.containsMouse ? Qt.lighter(Colors.bg, 2.2) : Qt.darker(Colors.bg, 0.6))

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.armed ? Colors.textDark : Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 19 * root.uiScale
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.needsConfirm || root.armed)
                    root.activated();
                else
                    root.arm();
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.armed ? "¿seguro?" : root.label
        color: root.armed ? Colors.accent : Colors.fg
        opacity: root.armed ? 1 : 0.7
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
    }
}
