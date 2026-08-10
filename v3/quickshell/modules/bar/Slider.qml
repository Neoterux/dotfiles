import QtQuick
import "../../theme"

// Barra deslizable simple (sin QtQuick.Controls) para usar dentro de
// popups, p.ej. el volumen. `value` va de 0.0 a 1.0.
Item {
    id: root

    property real uiScale: 1.0
    implicitWidth: 180 * uiScale
    implicitHeight: 20 * uiScale

    property real value: 0.5
    property color trackColor: Qt.darker(Colors.bg, 1.4)
    property color fillColor: Colors.accent

    signal moved(real value)

    function setFromX(x) {
        const v = Math.max(0, Math.min(1, x / track.width));
        root.value = v;
        root.moved(v);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 7 * root.uiScale
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }
    }

    Rectangle {
        width: 14 * root.uiScale
        height: 14 * root.uiScale
        radius: width / 2
        color: root.fillColor
        anchors.verticalCenter: track.verticalCenter
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.setFromX(mouse.x);
        }
    }
}
