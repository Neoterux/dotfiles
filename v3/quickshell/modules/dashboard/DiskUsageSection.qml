import QtQuick
import QtQuick.Layouts
import "../../theme"

// Lista de particiones montadas (ver PerformanceTab.qml por el `df` que
// llena `disks`) con una barra de uso + espacio libre por cada una.
ColumnLayout {
    id: root

    property real uiScale: 1.0
    property var disks: []

    Layout.fillWidth: true
    spacing: 10 * root.uiScale

    function fmtSize(bytes) {
        const gib = bytes / (1024 * 1024 * 1024);
        if (gib >= 1024)
            return (gib / 1024).toFixed(1) + "TiB";
        return gib.toFixed(1) + "GiB";
    }

    Repeater {
        model: root.disks

        delegate: ColumnLayout {
            id: diskRow
            required property var modelData

            readonly property real usedFrac: diskRow.modelData.size > 0 ? diskRow.modelData.used / diskRow.modelData.size : 0
            readonly property color barColor: diskRow.usedFrac > 0.9 ? Colors.network : (diskRow.usedFrac > 0.75 ? Colors.memory : Colors.cpu)

            Layout.fillWidth: true
            spacing: 4 * root.uiScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.uiScale

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: diskRow.modelData.target
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 12 * root.uiScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: diskRow.modelData.source.replace("/dev/", "") + " · " + diskRow.modelData.fstype
                    color: Colors.fg
                    opacity: 0.4
                    font.family: Colors.fontFamily
                    font.pixelSize: 10 * root.uiScale
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 7 * root.uiScale
                radius: height / 2
                color: Qt.darker(Colors.bg, 1.4)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, diskRow.usedFrac))
                    height: parent.height
                    radius: parent.radius
                    color: diskRow.barColor

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: root.fmtSize(diskRow.modelData.used) + " usados de " + root.fmtSize(diskRow.modelData.size) + " · " + root.fmtSize(diskRow.modelData.avail) + " libres"
                color: Colors.fg
                opacity: 0.55
                font.family: Colors.fontFamily
                font.pixelSize: 10 * root.uiScale
            }
        }
    }

    Text {
        visible: root.disks.length === 0
        text: "sin datos de disco"
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.italic: true
    }
}
