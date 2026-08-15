import QtQuick
import QtQuick.Layouts
import "../../theme"

// Fila "icono en circulo + texto" de la columna izquierda de
// DashboardTab.qml (distro/compositor/uptime) -- mismo formato de avatar
// que las filas de NetworkStatus/BluetoothDeviceSection, para que toda la
// UI comparta el mismo lenguaje visual en vez de iconos sueltos sin fondo.
RowLayout {
    id: root

    property real uiScale: 1.0
    property string icon: ""
    property string label: ""

    spacing: 10 * root.uiScale

    Rectangle {
        Layout.preferredWidth: 24 * root.uiScale
        Layout.preferredHeight: 24 * root.uiScale
        radius: width / 2
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: Colors.accent
            font.family: Colors.fontFamily
            font.pixelSize: 11 * root.uiScale
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.label
        color: Colors.fg
        font.family: Colors.fontFamily
        font.pixelSize: 12 * root.uiScale
        elide: Text.ElideRight
    }
}
