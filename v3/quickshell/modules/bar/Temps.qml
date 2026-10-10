import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../drawer"

// Temperaturas en la barra: CPU, GPU (borde/hotspot), VRAM y cada NVMe,
// cada una con su icono en el color que usa el dashboard. El valor pasa a
// amarillo/rojo segun los umbrales de cada tipo de sensor (ver
// TempSensors.classify). Al pasar el mouse, un drawer con TODOS los
// sensores de cada chip, incluidos los que no ganan lugar en la barra.
//
// La lectura vive en el singleton TempSensors: este modulo solo dibuja,
// asi las dos barras (una por monitor) no leen los mismos archivos dos
// veces.
Pill {
    id: root

    required property var panelWindow
    property bool expanded: false

    bg: Colors.bg
    fg: Colors.fg
    interactive: true
    visible: TempSensors.barEntries.length > 0

    function tempColor(s) {
        if (isNaN(s.celsius))
            return Colors.fg;
        if (s.celsius >= s.hot)
            return Colors.statusDown;
        if (s.celsius >= s.warn)
            return Colors.statusDegraded;
        return Colors.fg;
    }

    function tempText(s) {
        return isNaN(s.celsius) ? "—" : s.celsius + "°";
    }

    Repeater {
        model: TempSensors.barEntries

        delegate: RowLayout {
            id: entry
            required property var modelData
            required property int index
            spacing: 3 * root.uiScale

            // Separacion extra entre entries: el spacing del Pill (5px)
            // las dejaba pegadas y "41° 32°" se leia como un solo numero.
            Item {
                visible: entry.index > 0
                implicitWidth: 4 * root.uiScale
            }

            Text {
                text: entry.modelData.icon
                color: entry.modelData.tint
                font.family: Colors.fontFamily
                font.pixelSize: root.fontPixelSize
            }

            // Row sin spacing: el del RowLayout separaba "33°" de "/39°".
            Row {
                Repeater {
                    model: entry.modelData.sensors

                    delegate: Text {
                        id: value
                        required property var modelData
                        required property int index
                        // GPU: "33°/39°" (borde/hotspot) en vez de "33° 39°".
                        text: (value.index > 0 ? "/" : "") + root.tempText(value.modelData)
                        color: root.tempColor(value.modelData)
                        font.family: Colors.fontFamily
                        font.pixelSize: root.fontPixelSize
                    }
                }
            }
        }
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

            Text {
                // nf-fa-thermometer_half
                text: "\u{f2c9}  Temperaturas"
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
                font.bold: true
            }

            Repeater {
                model: TempSensors.devices

                delegate: ColumnLayout {
                    id: device
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 3 * root.uiScale

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.workspaceBorder
                        opacity: 0.25
                    }

                    RowLayout {
                        spacing: 6 * root.uiScale

                        Text {
                            text: device.modelData.title
                            color: Colors.fg
                            opacity: 0.85
                            font.family: Colors.fontFamily
                            font.pixelSize: 12 * root.uiScale
                            font.bold: true
                        }

                        Text {
                            text: device.modelData.subtitle
                            color: Colors.fg
                            opacity: 0.4
                            font.family: Colors.fontFamily
                            font.pixelSize: 10 * root.uiScale
                        }
                    }

                    Repeater {
                        model: device.modelData.sensors

                        delegate: RowLayout {
                            id: row
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 16 * root.uiScale

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 140 * root.uiScale
                                text: row.modelData.label || "temp"
                                color: Colors.fg
                                opacity: row.modelData.onBar ? 0.9 : 0.6
                                font.family: Colors.fontFamily
                                font.pixelSize: 12 * root.uiScale
                            }

                            Text {
                                text: isNaN(row.modelData.celsius) ? "—" : row.modelData.celsius + " °C"
                                color: root.tempColor(row.modelData)
                                font.family: Colors.fontFamily
                                font.pixelSize: 12 * root.uiScale
                                font.bold: row.modelData.onBar
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            Text {
                text: "CPU/GPU cada " + TempSensors.fastInterval / 1000 + "s · discos cada " + TempSensors.slowInterval / 1000 + "s"
                color: Colors.fg
                opacity: 0.4
                font.family: Colors.fontFamily
                font.pixelSize: 10 * root.uiScale
            }
        }
    }
}
