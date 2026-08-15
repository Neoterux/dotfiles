import QtQuick
import QtQuick.Layouts
import "../../theme"

// Tarjeta tenida generica para el tab "Dashboard" -- mismo formulazo de
// MetricCard (Performance): fondo/borde tenidos del color que se le pase,
// para que el tab lea como una grilla de bloques en vez de texto suelto.
//
// El ancho lo fija quien la usa (Layout.preferredWidth), pero el alto
// tiene que salir DEL contenido -- por eso `inner` (donde caen los hijos,
// via el alias de mas abajo) no usa `anchors.fill: parent`: eso haria que
// el alto dependiera del alto del Rectangle, que es lo que se esta
// tratando de calcular. En cambio se ancla solo left/right/top y el
// Rectangle toma su implicitHeight DE `inner`.
Rectangle {
    id: root

    property real uiScale: 1.0
    property color tint: Colors.accent

    default property alias content: inner.data

    implicitWidth: inner.implicitWidth + 28 * uiScale
    implicitHeight: inner.implicitHeight + 28 * uiScale
    radius: 16 * uiScale
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.08)
    border.width: 1
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.22)

    ColumnLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14 * root.uiScale
        spacing: 10 * root.uiScale
    }
}
