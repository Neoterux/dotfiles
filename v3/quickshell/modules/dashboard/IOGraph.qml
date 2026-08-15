import QtQuick
import QtQuick.Layouts
import "../../theme"

// Sparkline de lectura/escritura de disco (Canvas, mismo criterio que
// RingGauge -- sin QtQuick.Shapes). `readHistory`/`writeHistory` son
// arrays de bytes/segundo, mismo largo, mas nuevo al final -- los llena
// PerformanceTab.qml muestreando /proc/diskstats.
ColumnLayout {
    id: root

    property real uiScale: 1.0
    property var readHistory: []
    property var writeHistory: []
    property color readColor: Colors.clock
    property color writeColor: Colors.backlight

    Layout.fillWidth: true
    spacing: 6 * root.uiScale

    function fmtRate(bps) {
        if (bps < 1024)
            return Math.round(bps) + " B/s";
        if (bps < 1024 * 1024)
            return (bps / 1024).toFixed(1) + " KB/s";
        return (bps / 1024 / 1024).toFixed(1) + " MB/s";
    }

    readonly property real currentRead: root.readHistory.length > 0 ? root.readHistory[root.readHistory.length - 1] : 0
    readonly property real currentWrite: root.writeHistory.length > 0 ? root.writeHistory[root.writeHistory.length - 1] : 0
    // Piso de 1MiB/s para que el grafico no se vaya a extremos con el
    // ruido de un sistema inactivo (una lectura de 40KB/s sola llenando
    // todo el alto del grafico se ve peor que informativo).
    readonly property real maxVal: Math.max(1024 * 1024, ...root.readHistory, ...root.writeHistory)

    RowLayout {
        Layout.fillWidth: true
        spacing: 16 * root.uiScale

        RowLayout {
            spacing: 6 * root.uiScale
            Rectangle {
                Layout.preferredWidth: 8 * root.uiScale
                Layout.preferredHeight: 8 * root.uiScale
                radius: width / 2
                color: root.readColor
            }
            Text {
                text: "Lectura " + root.fmtRate(root.currentRead)
                color: Colors.fg
                opacity: 0.75
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
            }
        }

        RowLayout {
            spacing: 6 * root.uiScale
            Rectangle {
                Layout.preferredWidth: 8 * root.uiScale
                Layout.preferredHeight: 8 * root.uiScale
                radius: width / 2
                color: root.writeColor
            }
            Text {
                text: "Escritura " + root.fmtRate(root.currentWrite)
                color: Colors.fg
                opacity: 0.75
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 70 * root.uiScale
        radius: 10 * root.uiScale
        color: Qt.darker(Colors.bg, 1.3)
        clip: true

        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 4 * root.uiScale

            function pathFor(ctx, history, w, h) {
                const n = history.length;
                ctx.beginPath();
                for (let i = 0; i < n; i++) {
                    const x = n > 1 ? (i / (n - 1)) * w : w;
                    const y = h - Math.min(1, history[i] / root.maxVal) * h;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
            }

            function drawSeries(ctx, history, color, w, h) {
                if (history.length < 2)
                    return;

                pathFor(ctx, history, w, h);
                ctx.lineTo(w, h);
                ctx.lineTo(0, h);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.16);
                ctx.fill();

                pathFor(ctx, history, w, h);
                ctx.lineWidth = 1.6 * root.uiScale;
                ctx.strokeStyle = color;
                ctx.stroke();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineJoin = "round";
                drawSeries(ctx, root.readHistory, root.readColor, width, height);
                drawSeries(ctx, root.writeHistory, root.writeColor, width, height);
            }
        }
    }

    onReadHistoryChanged: canvas.requestPaint()
    onWriteHistoryChanged: canvas.requestPaint()
    Component.onCompleted: canvas.requestPaint()
}
