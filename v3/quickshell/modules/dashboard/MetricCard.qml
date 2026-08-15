import QtQuick
import QtQuick.Layouts
import "../../theme"

// Tarjeta para cada metrica de PerformanceTab (GPU/CPU/RAM/Reloj) --
// agrupa el RingGauge bajo un titulo, con un fondo tenue del mismo color
// que el anillo, para que cada metrica se lea como su propio bloque en
// vez de 4 anillos sueltos flotando en una fila sobre el fondo del drawer.
Rectangle {
    id: root

    property real uiScale: 1.0
    property string label: ""
    property color tint: Colors.accent

    default property alias content: inner.data

    implicitWidth: inner.implicitWidth + 26 * uiScale
    implicitHeight: inner.implicitHeight + 20 * uiScale
    radius: 16 * uiScale
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.10)
    border.width: 1
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.3)

    ColumnLayout {
        id: inner
        anchors.centerIn: parent
        spacing: 10 * root.uiScale

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: root.tint
            font.family: Colors.fontFamily
            font.pixelSize: 12 * root.uiScale
            font.bold: true
        }
    }
}
