import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../theme"
import "../drawer"

// Equivalente a "wireplumber" de waybar, pero leyendo Pipewire directo
// (sin pasar por wpctl) para que el volumen se actualice reactivamente.
//
// Los iconos van como escapes unicode (\uXXXX / surrogate pairs), no como
// glifo pegado: pegar el caracter del Nerd Font directo termino guardando
// un string vacio para varios modulos.
Pill {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volumePct: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    // Dispositivos de salida disponibles (parlantes, auriculares, HDMI,
    // etc.) -- isStream descarta los nodos de aplicaciones (esos son
    // "streams" que APUNTAN a un sink, no sinks en si).
    readonly property var audioSinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    required property var panelWindow
    property bool expanded: false

    bg: Colors.volume
    fg: Colors.textDark
    interactive: true

    // Mantiene el nodo "trackeado" para recibir sus cambios de volumen/mute.
    // name/description/isSink son constantes (no hace falta trackear los
    // demas sinks solo para listarlos en el selector).
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Text {
        // nf-fa-volume_off (mute, plano astral U+F075F) / nf-fa-volume_up (U+F028).
        // Como escape unicode literal: pegar el glifo termino guardando
        // string vacio de forma intermitente durante la edicion.
        text: (root.muted ? "\u{f075f} " : "\u{f028} ") + root.volumePct + "%"
        color: root.fg
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize
    }

    Process {
        id: mixer
        command: ["kitty", "--", "alsamixer", "-V", "all"]
    }

    onLeftClicked: root.expanded = !root.expanded
    onRightClicked: {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }
    onWheelUp: {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.min(1.5, root.sink.audio.volume + 0.05);
    }
    onWheelDown: {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, root.sink.audio.volume - 0.05);
    }

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        ColumnLayout {
            spacing: 12 * root.uiScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * root.uiScale

                Text {
                    text: root.sink ? root.sink.description : "sin salida de audio"
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 13 * root.uiScale
                    elide: Text.ElideRight
                    Layout.preferredWidth: 180 * root.uiScale
                }

                Text {
                    text: root.volumePct + "%"
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 13 * root.uiScale
                    font.bold: true
                }
            }

            RowLayout {
                spacing: 10 * root.uiScale

                Text {
                    // mismo par de iconos mute/volumen que el pill de arriba
                    text: root.muted ? "\u{f075f}" : "\u{f028}"
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 15 * root.uiScale

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.sink && root.sink.audio)
                                root.sink.audio.muted = !root.sink.audio.muted;
                        }
                    }
                }

                Slider {
                    uiScale: root.uiScale
                    value: root.sink && root.sink.audio ? root.sink.audio.volume / 1.5 : 0
                    onMoved: v => {
                        if (root.sink && root.sink.audio)
                            root.sink.audio.volume = v * 1.5;
                    }
                }
            }

            Text {
                text: "abrir mezclador (alsamixer)"
                color: Colors.fg
                opacity: 0.7
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.underline: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.expanded = false;
                        mixer.startDetached();
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.workspaceBorder
                opacity: 0.25
            }

            Text {
                text: "salida de audio"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.uiScale

                Repeater {
                    model: root.audioSinks

                    delegate: Item {
                        id: sinkDelegate
                        required property var modelData
                        readonly property bool isDefault: root.sink && sinkDelegate.modelData.id === root.sink.id

                        Layout.fillWidth: true
                        implicitHeight: sinkRow.implicitHeight + 8 * root.uiScale

                        Rectangle {
                            anchors.fill: parent
                            radius: 6 * root.uiScale
                            color: sinkDelegate.isDefault ? Qt.darker(Colors.bg, 0.6) : (sinkArea.containsMouse ? Qt.lighter(Colors.bg, 1.6) : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                        }

                        RowLayout {
                            id: sinkRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 6 * root.uiScale
                            spacing: 8 * root.uiScale

                            Text {
                                text: sinkDelegate.isDefault ? "\u{f00c}" : ""
                                color: Colors.accent
                                font.family: Colors.fontFamily
                                font.pixelSize: 11 * root.uiScale
                                Layout.preferredWidth: 12 * root.uiScale
                            }

                            Text {
                                Layout.fillWidth: true
                                text: sinkDelegate.modelData.description || sinkDelegate.modelData.name
                                color: Colors.fg
                                opacity: sinkDelegate.isDefault ? 1 : 0.75
                                font.family: Colors.fontFamily
                                font.pixelSize: 12 * root.uiScale
                                font.bold: sinkDelegate.isDefault
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: sinkArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Pipewire.preferredDefaultAudioSink = sinkDelegate.modelData
                        }
                    }
                }

                Text {
                    visible: root.audioSinks.length === 0
                    text: "sin salidas detectadas"
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 11 * root.uiScale
                    font.italic: true
                }
            }
        }
    }
}
