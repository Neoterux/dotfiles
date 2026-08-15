import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../theme"

// Pestaña "Media": control MPRIS (Spotify, browsers, mpv, lo que sea que
// hable el protocolo). Si no hay ningun reproductor activo, muestra un
// estado vacio en vez de quedar en blanco.
Item {
    id: root

    property real uiScale: 1.0
    implicitWidth: 360 * uiScale
    implicitHeight: player ? 190 * uiScale : 90 * uiScale

    readonly property var players: Mpris.players.values
    readonly property var player: players.length > 0 ? players[0] : null

    function fmtTime(secs) {
        if (!secs || secs < 0)
            return "0:00";
        const m = Math.floor(secs / 60);
        const s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.player
        spacing: 10 * root.uiScale

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\u{f001}" // nf-fa-music
            color: Colors.fg
            opacity: 0.4
            font.family: Colors.fontFamily
            font.pixelSize: 26 * root.uiScale
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "nada sonando"
            color: Colors.fg
            opacity: 0.5
            font.family: Colors.fontFamily
            font.pixelSize: 13 * root.uiScale
        }
    }

    // Tarjeta con tinte del acento, mismo criterio visual que MetricCard
    // (Performance) y los drawers de red/bluetooth -- consistencia con el
    // resto del dashboard en vez de controles sueltos flotando.
    Rectangle {
        anchors.fill: parent
        visible: !!root.player
        radius: 18 * root.uiScale
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.08)
        border.width: 1
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16 * root.uiScale
            spacing: 14 * root.uiScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 14 * root.uiScale

                Rectangle {
                    Layout.preferredWidth: 68 * root.uiScale
                    Layout.preferredHeight: 68 * root.uiScale
                    radius: 14 * root.uiScale
                    color: Qt.darker(Colors.bg, 0.55)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || root.player.trackArtUrl === ""
                        text: "\u{f001}" // nf-fa-music
                        color: Colors.fg
                        opacity: 0.4
                        font.family: Colors.fontFamily
                        font.pixelSize: 22 * root.uiScale
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3 * root.uiScale

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.player ? root.player.trackTitle : ""
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 15 * root.uiScale
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.player ? root.player.trackArtist : ""
                        color: Colors.accent
                        font.family: Colors.fontFamily
                        font.pixelSize: 12 * root.uiScale
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.player ? root.player.trackAlbum : ""
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 11 * root.uiScale
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.uiScale

                Rectangle {
                    Layout.fillWidth: true
                    height: 5 * root.uiScale
                    radius: height / 2
                    color: Qt.darker(Colors.bg, 0.55)

                    Rectangle {
                        readonly property real frac: (root.player && root.player.length > 0) ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                        width: parent.width * frac
                        height: parent.height
                        radius: parent.radius
                        color: Colors.accent
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.player ? root.fmtTime(root.player.position) : "0:00"
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 10 * root.uiScale
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.player ? root.fmtTime(root.player.length) : "0:00"
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 10 * root.uiScale
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 22 * root.uiScale

                Item {
                    Layout.preferredWidth: 34 * root.uiScale
                    Layout.preferredHeight: 34 * root.uiScale

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: prevArea.containsMouse ? Qt.lighter(Colors.bg, 1.8) : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f048}" // nf-fa-step_backward
                        color: Colors.fg
                        opacity: root.player && root.player.canGoPrevious ? 1 : 0.3
                        font.family: Colors.fontFamily
                        font.pixelSize: 14 * root.uiScale
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canGoPrevious)
                            root.player.previous()
                    }
                }

                Item {
                    Layout.preferredWidth: 46 * root.uiScale
                    Layout.preferredHeight: 46 * root.uiScale

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: playArea.containsMouse ? Qt.lighter(Colors.accent, 1.15) : Colors.accent

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (root.player && root.player.isPlaying) ? "\u{f04c}" : "\u{f04b}" // nf-fa-pause / nf-fa-play
                        color: Colors.textDark
                        font.family: Colors.fontFamily
                        font.pixelSize: 17 * root.uiScale
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player)
                            root.player.togglePlaying()
                    }
                }

                Item {
                    Layout.preferredWidth: 34 * root.uiScale
                    Layout.preferredHeight: 34 * root.uiScale

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: nextArea.containsMouse ? Qt.lighter(Colors.bg, 1.8) : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\u{f051}" // nf-fa-step_forward
                        color: Colors.fg
                        opacity: root.player && root.player.canGoNext ? 1 : 0.3
                        font.family: Colors.fontFamily
                        font.pixelSize: 14 * root.uiScale
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canGoNext)
                            root.player.next()
                    }
                }
            }
        }
    }
}
