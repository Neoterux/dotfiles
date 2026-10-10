import QtQuick

// Grafico de linea + relleno para una serie 0..1, mas nuevo a la derecha.
Canvas {
    id: root

    property var history: []
    property int historyLen: 45
    property color color: "#ebdbb2"
    property real lineWidth: 1.2
    property real fillAlpha: 0.22

    onHistoryChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function trace(ctx, w, h, lw) {
        const n = root.history.length;
        const step = w / Math.max(1, root.historyLen - 1);
        const x0 = w - (n - 1) * step;
        const top = lw / 2;
        const span = h - lw;
        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const x = x0 + i * step;
            const y = top + (1 - Math.max(0, Math.min(1, root.history[i]))) * span;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        return x0;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (root.history.length < 2)
            return;

        const w = root.width;
        const h = root.height;
        ctx.lineJoin = "round";

        const x0 = root.trace(ctx, w, h, root.lineWidth);
        ctx.lineTo(w, h);
        ctx.lineTo(x0, h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.fillAlpha);
        ctx.fill();

        root.trace(ctx, w, h, root.lineWidth);
        ctx.lineWidth = root.lineWidth;
        ctx.strokeStyle = root.color;
        ctx.stroke();
    }
}
