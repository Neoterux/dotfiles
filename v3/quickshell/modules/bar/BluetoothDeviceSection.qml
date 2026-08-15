import QtQuick
import QtQuick.Layouts
import "../../theme"

// Una seccion de la lista de bluetooth (Conectados/Emparejados/Disponibles)
// -- se repite 3 veces en BluetoothButton.qml, de ahi el componente propio
// en vez de duplicar la fila 3 veces.
ColumnLayout {
    id: root

    property real uiScale: 1.0
    property string title: ""
    property var devices: []

    // Glifo por categoria en vez de `Quickshell.iconPath(bluezIconName)`:
    // probado en vivo, el theme de iconos de esta maquina resuelve pero no
    // *carga* nombres freedesktop comunes (input-gaming, audio-card,
    // network-wired, bluetooth, etc. -- todos con
    // "WARN: Could not load icon" en el log pese a `status === Image.Ready`,
    // asi que ese `status` no sirve para detectar la falla y el circulo
    // terminaba mostrando el cuadriculado magenta/negro de "imagen rota").
    // Glifos son 100% confiables aca porque es el mismo mecanismo que ya
    // usa el resto de la barra.
    function deviceGlyph(iconName) {
        const n = (iconName || "").toLowerCase();
        if (n.indexOf("gaming") !== -1 || n.indexOf("joystick") !== -1)
            return ""; // nf-fa-gamepad
        if (n.indexOf("headset") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("audio") !== -1)
            return ""; // nf-fa-headphones
        if (n.indexOf("phone") !== -1)
            return ""; // nf-fa-mobile
        if (n.indexOf("keyboard") !== -1)
            return ""; // nf-fa-keyboard_o
        if (n.indexOf("mouse") !== -1)
            return ""; // nf-fa-mouse_pointer
        if (n.indexOf("computer") !== -1 || n.indexOf("desktop") !== -1)
            return ""; // nf-fa-desktop, mismo glifo que DashboardTab.qml
        if (n.indexOf("printer") !== -1)
            return ""; // nf-fa-print
        if (n.indexOf("camera") !== -1)
            return ""; // nf-fa-camera
        return ""; // nf-fa-bluetooth_b, mismo glifo que el boton de la barra
    }

    Layout.fillWidth: true
    visible: root.devices.length > 0
    spacing: 4 * root.uiScale

    Text {
        text: root.title
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.bold: true
    }

    Repeater {
        model: root.devices

        delegate: Item {
            id: devRow
            required property var modelData
            property bool forgetArmed: false

            Layout.fillWidth: true
            implicitHeight: devLayout.implicitHeight + 10 * root.uiScale

            Rectangle {
                anchors.fill: parent
                radius: 8 * root.uiScale
                color: devRow.modelData.connected ? Qt.darker(Colors.bg, 0.6) : (rowArea.containsMouse ? Qt.lighter(Colors.bg, 1.6) : "transparent")

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            RowLayout {
                id: devLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 7 * root.uiScale
                spacing: 10 * root.uiScale

                Rectangle {
                    Layout.preferredWidth: 28 * root.uiScale
                    Layout.preferredHeight: 28 * root.uiScale
                    radius: width / 2
                    color: devRow.modelData.connected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22) : Qt.darker(Colors.bg, 0.5)

                    Text {
                        anchors.centerIn: parent
                        text: root.deviceGlyph(devRow.modelData.icon)
                        color: devRow.modelData.connected ? Colors.accent : Colors.fg
                        opacity: devRow.modelData.connected ? 1 : 0.7
                        font.family: Colors.fontFamily
                        font.pixelSize: 13 * root.uiScale
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1 * root.uiScale

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: devRow.modelData.name
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 12 * root.uiScale
                        font.bold: devRow.modelData.connected
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        text: {
                            if (devRow.modelData.pairing)
                                return "emparejando...";
                            if (devRow.modelData.connected && devRow.modelData.batteryAvailable)
                                return "conectado · " + Math.round(devRow.modelData.battery * 100) + "%";
                            if (devRow.modelData.connected)
                                return "conectado";
                            if (devRow.modelData.paired)
                                return "emparejado";
                            return "disponible";
                        }
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 10 * root.uiScale
                    }
                }

                ActionChip {
                    visible: devRow.modelData.connected
                    uiScale: root.uiScale
                    text: "Desconectar"
                    tint: Colors.network
                    variant: "outline"
                    onClicked: devRow.modelData.disconnect()
                }

                ActionChip {
                    visible: !devRow.modelData.connected && devRow.modelData.paired && !devRow.modelData.pairing
                    uiScale: root.uiScale
                    text: "Conectar"
                    tint: Colors.accent
                    variant: "filled"
                    onClicked: devRow.modelData.connect()
                }

                ActionChip {
                    visible: !devRow.modelData.paired && !devRow.modelData.pairing
                    uiScale: root.uiScale
                    text: "Emparejar"
                    tint: Colors.accent
                    variant: "filled"
                    onClicked: devRow.modelData.pair()
                }

                ActionChip {
                    visible: devRow.modelData.pairing
                    uiScale: root.uiScale
                    text: "Cancelar"
                    tint: Colors.network
                    variant: "outline"
                    onClicked: devRow.modelData.cancelPair()
                }

                ActionChip {
                    visible: devRow.modelData.paired && !devRow.modelData.connected
                    uiScale: root.uiScale
                    text: devRow.forgetArmed ? "¿Olvidar?" : "Olvidar"
                    tint: Colors.network
                    variant: "outline"
                    onClicked: {
                        if (devRow.forgetArmed) {
                            devRow.modelData.forget();
                            devRow.forgetArmed = false;
                        } else {
                            devRow.forgetArmed = true;
                        }
                    }
                }
            }
        }
    }
}
