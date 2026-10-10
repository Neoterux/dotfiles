import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../drawer"

// Graficos de CPU y RAM en la barra; en grande en el drawer.
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

    // Ancho fijo para que la barra no salte al cambiar de digitos.
    TextMetrics {
        id: pctMetrics
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize
        text: "99%"
    }

    // Inline y no Repeater: el Repeater recrearia los Canvas en cada muestra.
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
        // nf-fa-microchip
        icon: "\u{f2db}"
        tint: Colors.cpu
        history: SysUsage.cpuHistory
        value: SysUsage.cpu
    }

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
