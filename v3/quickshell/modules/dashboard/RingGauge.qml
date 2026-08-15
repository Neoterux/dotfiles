import QtQuick
import QtQuick.Effects
import "../../theme"

// Anillo de progreso circular (Canvas, sin depender de QtQuick.Shapes)
// para las metricas de Performance -- inspirado en los anillos de
// CPU/GPU/memoria del dashboard de caelestia-dots/shell.
Item {
    id: root

    property real uiScale: 1.0
    property real size: 100
    implicitWidth: size * uiScale
    implicitHeight: size * uiScale

    property real value: 0 // 0..1
    property color ringColor: Colors.accent
    property color trackColor: Qt.darker(Colors.bg, 0.55)
    property string bigText: ""
    property string smallText: ""
    property real lineWidth: 8 * uiScale

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(width, height) / 2 - root.lineWidth;
            const startAngle = -Math.PI / 2;
            const endAngle = startAngle + Math.PI * 2 * Math.max(0, Math.min(1, root.value));

            ctx.lineWidth = root.lineWidth;
            ctx.lineCap = "round";

            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();

            if (root.value > 0) {
                ctx.strokeStyle = root.ringColor;
                ctx.beginPath();
                ctx.arc(cx, cy, r, startAngle, endAngle);
                ctx.stroke();
            }
        }
    }

    // Brillo sutil detras del anillo, tenido del mismo color -- sin esto
    // los anillos se leian planos/flotando sobre el fondo del drawer.
    MultiEffect {
        anchors.fill: canvas
        source: canvas
        z: canvas.z - 1
        shadowEnabled: true
        shadowColor: root.ringColor
        shadowOpacity: 0.55
        shadowBlur: 0.7
        blurMax: 24
    }

    Behavior on value {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    onValueChanged: canvas.requestPaint()
    onRingColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()

    Column {
        anchors.centerIn: parent
        spacing: -2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.bigText
            color: Colors.fg
            font.family: Colors.fontFamily
            font.pixelSize: 18 * root.uiScale
            font.bold: true
        }

        Text {
            visible: root.smallText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.smallText
            color: Colors.fg
            opacity: 0.6
            font.family: Colors.fontFamily
            font.pixelSize: 11 * root.uiScale
        }
    }
}
