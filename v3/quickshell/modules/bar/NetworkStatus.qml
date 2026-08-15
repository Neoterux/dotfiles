import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking
import "../../theme"
import "../drawer"

// Icono de red + drawer completo (wifi y cableado). El icono en si sigue
// derivando el estado de `ip -j route show default` (ver comentario
// original mas abajo): es lo mas simple para decidir el glifo/color sin
// importar el backend. El contenido del drawer, en cambio, usa
// Quickshell.Networking (NetworkManager via DBus, reactivo) para listar
// y controlar redes de verdad -- separar ambas cosas evita que el icono
// de la barra dependa de que exista un dispositivo wifi/NetworkManager.
IconButton {
    id: root

    required property var panelWindow
    property bool expanded: false

    property bool online: false
    property string iface: ""

    // Cableado: md-ethernet (el puerto RJ45), no fa-plug -- ese es un
    // enchufe/conector generico y no se lee como "red por cable".
    icon: online ? (iface.startsWith("wl") ? "\u{f1eb}" : "\u{f0200}") : "\u{f092d}"
    active: online
    fontScale: online && !iface.startsWith("wl") ? 1.05 : 1.15

    readonly property var wifiDevice: {
        const list = Networking.devices.values.filter(d => d.type === DeviceType.Wifi);
        return list.length > 0 ? list[0] : null;
    }
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired);

    // Conectada primero, despues por intensidad de señal descendente.
    readonly property var sortedNetworks: {
        if (!root.wifiDevice)
            return [];
        const list = root.wifiDevice.networks.values.slice();
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return list;
    }

    readonly property color connectivityColor: {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return Colors.statusUp;
        case NetworkConnectivity.Limited:
        case NetworkConnectivity.Portal:
            return Colors.statusDegraded;
        case NetworkConnectivity.None:
            return Colors.statusDown;
        default:
            return Colors.statusUnknown;
        }
    }

    Process {
        id: proc
        command: ["ip", "-j", "route", "show", "default"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const routes = JSON.parse(text);
                    if (routes.length > 0) {
                        root.online = true;
                        root.iface = routes[0].dev;
                    } else {
                        root.online = false;
                        root.iface = "";
                    }
                } catch (e) {
                    root.online = false;
                    root.iface = "";
                }
            }
        }
    }

    Process {
        id: nmtui
        command: ["kitty", "--", "nmtui"]
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            proc.running = false;
            proc.running = true;
        }
    }

    onLeftClicked: root.expanded = !root.expanded
    onRightClicked: {
        if (root.wifiDevice)
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // Solo escanear mientras el drawer esta abierto -- scannerEnabled
    // mantiene el radio wifi buscando redes activamente, no tiene sentido
    // gastar eso (ni CPU actualizando la lista) si nadie la esta mirando.
    onExpandedChanged: {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.expanded;
    }

    NetworkPasswordPanel {
        id: pwPanel
        panelScreen: root.panelWindow.screen
        uiScale: root.uiScale
    }

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        ColumnLayout {
            // `width` explicito, no `Layout.preferredWidth`: el padre
            // directo (`inner` en Drawer.qml) es un Item plano, no un
            // Layout, asi que ese attached property no hace nada -- sin
            // esto, cada fila queda con un ancho distinto segun su propio
            // contenido y los ActionChip terminan aplastados/recortados.
            width: 320 * root.uiScale
            spacing: 12 * root.uiScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.uiScale

                Rectangle {
                    Layout.preferredWidth: 9 * root.uiScale
                    Layout.preferredHeight: 9 * root.uiScale
                    radius: width / 2
                    color: root.connectivityColor
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: NetworkConnectivity.toString(Networking.connectivity)
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            // --- Cableado ---
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.wiredDevices.length > 0
                spacing: 4 * root.uiScale

                Text {
                    text: "Cableado"
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 11 * root.uiScale
                    font.bold: true
                }

                Repeater {
                    model: root.wiredDevices

                    delegate: Item {
                        id: wiredRow
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: wiredLayout.implicitHeight + 10 * root.uiScale

                        Rectangle {
                            anchors.fill: parent
                            radius: 8 * root.uiScale
                            color: wiredRow.modelData.hasLink ? Qt.darker(Colors.bg, 0.6) : "transparent"
                        }

                        RowLayout {
                            id: wiredLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 7 * root.uiScale
                            spacing: 10 * root.uiScale

                            Rectangle {
                                Layout.preferredWidth: 28 * root.uiScale
                                Layout.preferredHeight: 28 * root.uiScale
                                radius: width / 2
                                color: wiredRow.modelData.hasLink ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22) : Qt.darker(Colors.bg, 0.5)

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u{f0200}" // md-ethernet, mismo glifo que el icono de la barra
                                    color: wiredRow.modelData.hasLink ? Colors.accent : Colors.fg
                                    opacity: wiredRow.modelData.hasLink ? 1 : 0.5
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
                                    text: wiredRow.modelData.name
                                    color: Colors.fg
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 13 * root.uiScale
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                    text: wiredRow.modelData.hasLink ? [wiredRow.modelData.address, wiredRow.modelData.linkSpeed > 0 ? wiredRow.modelData.linkSpeed + " Mbps" : ""].filter(s => s).join(" · ") : "sin enlace"
                                    color: Colors.fg
                                    opacity: 0.5
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11 * root.uiScale
                                }
                            }

                            ActionChip {
                                visible: wiredRow.modelData.hasLink
                                uiScale: root.uiScale
                                text: "Desconectar"
                                tint: Colors.network
                                variant: "outline"
                                onClicked: wiredRow.modelData.disconnect()
                            }

                            ActionChip {
                                visible: !wiredRow.modelData.hasLink && wiredRow.modelData.network
                                uiScale: root.uiScale
                                text: "Conectar"
                                tint: Colors.accent
                                variant: "filled"
                                onClicked: wiredRow.modelData.network.connect()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.wiredDevices.length > 0 && root.wifiDevice !== null
                height: 1
                color: Colors.workspaceBorder
                opacity: 0.25
            }

            // --- Wifi ---
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.wifiDevice !== null
                spacing: 6 * root.uiScale

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.uiScale

                    Text {
                        Layout.fillWidth: true
                        text: "Wi-Fi"
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 11 * root.uiScale
                        font.bold: true
                    }

                    // Switch on/off hecho a mano (sin QtQuick.Controls,
                    // mismo criterio que Slider.qml).
                    Item {
                        id: wifiToggle
                        Layout.preferredWidth: 32 * root.uiScale
                        Layout.preferredHeight: 17 * root.uiScale
                        enabled: Networking.wifiHardwareEnabled

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Networking.wifiEnabled ? Colors.accent : Qt.darker(Colors.bg, 0.5)
                            opacity: wifiToggle.enabled ? 1 : 0.4

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        Rectangle {
                            width: 13 * root.uiScale
                            height: 13 * root.uiScale
                            radius: width / 2
                            y: 2 * root.uiScale
                            color: Colors.fg
                            opacity: wifiToggle.enabled ? 1 : 0.4
                            x: Networking.wifiEnabled ? parent.width - width - 2 * root.uiScale : 2 * root.uiScale

                            Behavior on x {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: wifiToggle.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }
                }

                Text {
                    visible: !Networking.wifiHardwareEnabled
                    text: "deshabilitado por hardware (rfkill)"
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 11 * root.uiScale
                    font.italic: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: Networking.wifiEnabled && Networking.wifiHardwareEnabled
                    spacing: 2 * root.uiScale

                    Repeater {
                        model: root.sortedNetworks

                        delegate: Item {
                            id: netRow
                            required property var modelData
                            property bool forgetArmed: false

                            Layout.fillWidth: true
                            implicitHeight: netRowLayout.implicitHeight + 8 * root.uiScale

                            Rectangle {
                                anchors.fill: parent
                                radius: 6 * root.uiScale
                                color: netRow.modelData.connected ? Qt.darker(Colors.bg, 0.6) : (rowArea.containsMouse ? Qt.lighter(Colors.bg, 1.6) : "transparent")

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
                                id: netRowLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 7 * root.uiScale
                                spacing: 10 * root.uiScale

                                Rectangle {
                                    Layout.preferredWidth: 28 * root.uiScale
                                    Layout.preferredHeight: 28 * root.uiScale
                                    radius: width / 2
                                    color: netRow.modelData.connected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22) : Qt.darker(Colors.bg, 0.5)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 2 * root.uiScale

                                        Repeater {
                                            model: 4

                                            delegate: Rectangle {
                                                id: bar
                                                required property int index
                                                readonly property int filled: Math.ceil(netRow.modelData.signalStrength / 25)

                                                Layout.preferredWidth: 3 * root.uiScale
                                                Layout.preferredHeight: (4 + bar.index * 3) * root.uiScale
                                                Layout.alignment: Qt.AlignBottom
                                                radius: 1
                                                color: netRow.modelData.connected ? Colors.accent : Colors.fg
                                                opacity: bar.filled > bar.index ? 1 : 0.3
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1 * root.uiScale

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5 * root.uiScale

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: netRow.modelData.name
                                            color: Colors.fg
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 13 * root.uiScale
                                            font.bold: netRow.modelData.connected
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: netRow.modelData.security !== WifiSecurityType.Open
                                            text: "\u{f023}" // nf-fa-lock, mismo glifo que PowerMenu "bloquear"
                                            color: Colors.fg
                                            opacity: 0.6
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 10 * root.uiScale
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight
                                        text: netRow.modelData.stateChanging ? "conectando..." : (netRow.modelData.connected ? "conectada" : (netRow.modelData.known ? "guardada" : WifiSecurityType.toString(netRow.modelData.security)))
                                        color: Colors.fg
                                        opacity: 0.5
                                        font.family: Colors.fontFamily
                                        font.pixelSize: 11 * root.uiScale
                                    }
                                }

                                ActionChip {
                                    visible: netRow.modelData.connected
                                    uiScale: root.uiScale
                                    text: "Desconectar"
                                    tint: Colors.network
                                    variant: "outline"
                                    onClicked: netRow.modelData.disconnect()
                                }

                                ActionChip {
                                    visible: !netRow.modelData.connected && !netRow.modelData.stateChanging
                                    uiScale: root.uiScale
                                    text: "Conectar"
                                    tint: Colors.accent
                                    variant: "filled"
                                    onClicked: {
                                        if (netRow.modelData.known || netRow.modelData.security === WifiSecurityType.Open)
                                            netRow.modelData.connect();
                                        else
                                            pwPanel.openFor(netRow.modelData);
                                    }
                                }

                                ActionChip {
                                    visible: netRow.modelData.known && !netRow.modelData.connected
                                    uiScale: root.uiScale
                                    text: netRow.forgetArmed ? "¿Olvidar?" : "Olvidar"
                                    tint: Colors.network
                                    variant: "outline"
                                    onClicked: {
                                        if (netRow.forgetArmed) {
                                            netRow.modelData.forget();
                                            netRow.forgetArmed = false;
                                        } else {
                                            netRow.forgetArmed = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.sortedNetworks.length === 0
                        text: "buscando redes..."
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 11 * root.uiScale
                        font.italic: true
                    }
                }
            }

            Text {
                visible: root.wifiDevice === null && root.wiredDevices.length === 0
                text: "sin dispositivos de red"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.italic: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.workspaceBorder
                opacity: 0.25
            }

            Text {
                text: "abrir nmtui (avanzado)"
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
                        nmtui.startDetached();
                    }
                }
            }
        }
    }
}
