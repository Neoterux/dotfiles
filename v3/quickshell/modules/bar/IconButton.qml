import QtQuick
import "../../theme"

// Boton minimal solo-icono para la bandeja de la derecha (red, bluetooth,
// terminal, procesos, power menu) -- a diferencia de Pill, no tiene
// fondo de color propio, solo un highlight sutil al pasar el mouse.
Item {
    id: root

    property real uiScale: 1.0
    property string icon: "\u{f08c7} "
    property color iconColor: Colors.fg
    property bool active: false
    property real fontScale: 1

    // Mismo alto que Pill (24*uiScale, ver Pill.qml) -- antes era
    // 26*uiScale, un poco mas grande, lo que hacia que los applets de la
    // derecha (red, bluetooth, terminal, procesos, power) se vieran mas
    // grandes que los pills de la izquierda (Workspaces, Volume, etc.)
    // pese a compartir el mismo alto de barra (30*uiScale, ver shell.qml).
    implicitWidth: 24 * uiScale
    implicitHeight: 24 * uiScale

    signal leftClicked
    signal rightClicked

    default property alias extraContent: extra.data

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2 * root.uiScale
        radius: 8 * root.uiScale
        color: mouseArea.containsMouse ? Qt.lighter(Colors.bg, 2.2) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active ? Colors.accent : root.iconColor
        font.family: Colors.fontFamily
        font.pixelSize: 12 * root.uiScale * root.fontScale
    }

    // Contenedor para el contenido extra de cada instancia (p.ej. el
    // IconImage de un item de la bandeja). Tiene que llenar el boton: sin
    // esto queda 0x0 en la esquina y cualquier hijo con `centerIn: parent`
    // se dibuja fuera de la superficie de la barra (invisible).
    Item {
        id: extra
        anchors.fill: parent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.leftClicked();
        }
    }
}
