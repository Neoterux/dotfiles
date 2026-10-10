import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../drawer"

// Uso de CPU y RAM en la barra: icono + grafico del ultimo minuto y medio
// + porcentaje. Al pasar el mouse, los mismos graficos en grande con el
// detalle (GiB usados, swap). Los datos salen del singleton SysUsage.
Pill {
    id: root

    required property var panelWindow
    property bool expanded: false

    bg: Colors.bg
    fg: Colors.fg
    interactive: true

    function pct(v) {
        return Math.round(v * 100) + "%";
    }

    // Ancho fijo para el porcentaje: si no, la pill entera (y todo lo que
    // esta a su izquierda en la barra) salta cada vez que pasa de 9% a 10%.
    TextMetrics {
        id: pctMetrics
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize
        // "99%": 100% es raro y solo empuja un caracter; reservarle
        // lugar dejaba un hueco grande antes de "1%".
        text: "99%"
    }

    // Componentes inline y no un Repeater sobre un array de objetos: ese
    // array se reconstruye en cada muestra (cambia `history`), y el
    // Repeater destruiria y recrearia los Canvas cada 2s.
    component Segment: RowLayout {
        id: seg
        property string icon
        property color tint
        property var history: []
        property real value: 0
        spacing: 4 * root.uiScale

        Text {
            text: seg.icon
            color: seg.tint
            font.family: Colors.fontFamily
            font.pixelSize: root.fontPixelSize
        }

        Rectangle {
            implicitWidth: 46 * root.uiScale
            implicitHeight: 14 * root.uiScale
            radius: 3 * root.uiScale
            // Un velo claro y no un tono mas oscuro: contra la barra
            // translucida, Qt.darker(bg) no se distinguia del fondo.
            color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)

            Sparkline {
                anchors.fill: parent
                anchors.margins: 1
                history: seg.history
                historyLen: SysUsage.historyLen
                color: seg.tint
                lineWidth: Math.max(1, 1.2 * root.uiScale)
            }
        }

        Text {
            Layout.preferredWidth: pctMetrics.advanceWidth
            horizontalAlignment: Text.AlignRight
            text: root.pct(seg.value)
            color: root.fg
            font.family: Colors.fontFamily
            font.pixelSize: root.fontPixelSize
        }
    }

    component Card: ColumnLayout {
        id: card
        property string title
        property color tint
        property var history: []
        property real value: 0
        property string detail
        spacing: 4 * root.uiScale

        RowLayout {
            spacing: 8 * root.uiScale

            Text {
                text: card.title
                color: card.tint
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                font.bold: true
            }

            Text {
                text: root.pct(card.value)
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: card.detail
                color: Colors.fg
                opacity: 0.55
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            implicitWidth: 300 * root.uiScale
            implicitHeight: 56 * root.uiScale
            radius: 8 * root.uiScale
            color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.06)

            Sparkline {
                anchors.fill: parent
                anchors.margins: 4 * root.uiScale
                history: card.history
                historyLen: SysUsage.historyLen
                color: card.tint
                lineWidth: 1.6 * root.uiScale
                fillAlpha: 0.16
            }
        }
    }

    Segment {
        // nf-fa-microchip, el mismo icono que la CPU en Temps.qml
        icon: "\u{f2db}"
        tint: Colors.cpu
        history: SysUsage.cpuHistory
        value: SysUsage.cpu
    }

    // Separacion extra entre CPU y RAM (el spacing del Pill las pegaba).
    Item {
        implicitWidth: 4 * root.uiScale
    }

    Segment {
        // nf-md-memory
        icon: "\u{f035b}"
        tint: Colors.memory
        history: SysUsage.memHistory
        value: SysUsage.mem
    }

    onLeftClicked: root.expanded = !root.expanded

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded
        hoverOpen: true
        hoverSource: root
        onOpenRequested: root.expanded = true
        onCloseRequested: root.expanded = false
        onEscapePressed: root.expanded = false

        ColumnLayout {
            spacing: 10 * root.uiScale

            Card {
                title: "CPU"
                tint: Colors.cpu
                history: SysUsage.cpuHistory
                value: SysUsage.cpu
            }

            Card {
                title: "RAM"
                tint: Colors.memory
                history: SysUsage.memHistory
                value: SysUsage.mem
                detail: SysUsage.memUsedGiB.toFixed(1) + " / " + SysUsage.memTotalGiB.toFixed(1) + " GiB" + (SysUsage.swapTotalGiB > 0 ? "  ·  swap " + SysUsage.swapUsedGiB.toFixed(1) + " / " + SysUsage.swapTotalGiB.toFixed(1) + " GiB" : "")
            }

            Text {
                text: "ultimos " + (SysUsage.historyLen * SysUsage.interval / 1000) + "s · cada " + SysUsage.interval / 1000 + "s"
                color: Colors.fg
                opacity: 0.4
                font.family: Colors.fontFamily
                font.pixelSize: 10 * root.uiScale
            }
        }
    }
}
