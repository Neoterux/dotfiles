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
    implicitWidth: 340 * uiScale
    implicitHeight: player ? 140 * uiScale : 70 * uiScale

    readonly property var players: Mpris.players.values
    readonly property var player: players.length > 0 ? players[0] : null

    RowLayout {
        anchors.centerIn: parent
        visible: !root.player
        spacing: 10 * root.uiScale

        Text {
            text: ""
            color: Colors.fg
            opacity: 0.5
            font.family: Colors.fontFamily
            font.pixelSize: 18 * root.uiScale
        }

        Text {
            text: "nada sonando"
            color: Colors.fg
            opacity: 0.5
            font.family: Colors.fontFamily
            font.pixelSize: 14 * root.uiScale
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !!root.player
        spacing: 10 * root.uiScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 14 * root.uiScale

            Rectangle {
                Layout.preferredWidth: 64 * root.uiScale
                Layout.preferredHeight: 64 * root.uiScale
                radius: width / 2
                color: Qt.darker(Colors.bg, 0.6)
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
                    text: ""
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 20 * root.uiScale
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3 * root.uiScale

                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.player.trackTitle : ""
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.player.trackArtist : ""
                    color: Colors.fg
                    opacity: 0.65
                    font.family: Colors.fontFamily
                    font.pixelSize: 12 * root.uiScale
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.player.trackAlbum : ""
                    color: Colors.fg
                    opacity: 0.45
                    font.family: Colors.fontFamily
                    font.pixelSize: 11 * root.uiScale
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 4 * root.uiScale
            radius: height / 2
            color: Qt.darker(Colors.bg, 0.6)

            Rectangle {
                readonly property real frac: (root.player && root.player.length > 0) ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                width: parent.width * frac
                height: parent.height
                radius: parent.radius
                color: Colors.accent
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24 * root.uiScale

            Text {
                text: ""
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 16 * root.uiScale
                opacity: root.player && root.player.canGoPrevious ? 1 : 0.35

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canGoPrevious)
                        root.player.previous()
                }
            }

            Text {
                text: (root.player && root.player.isPlaying) ? "" : ""
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 19 * root.uiScale

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player)
                        root.player.togglePlaying()
                }
            }

            Text {
                text: ""
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 16 * root.uiScale
                opacity: root.player && root.player.canGoNext ? 1 : 0.35

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canGoNext)
                        root.player.next()
                }
            }
        }
    }
}
