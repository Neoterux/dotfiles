import QtQuick
import "../../theme"

// Chip clickeable chico para acciones dentro de una fila de un drawer
// (Conectar/Desconectar/Olvidar/Emparejar/Confiar, etc). Reemplaza los
// links de texto subrayado que usaban antes NetworkStatus/BluetoothButton
// -- se sentian mas a lista de un CLI que a una UI real. Compartido entre
// ambos (y cualquier otro drawer que necesite botones de accion chicos).
Item {
    id: root

    property real uiScale: 1.0
    property string text: ""
    property color tint: Colors.accent
    // "filled": fondo solido, texto oscuro (accion primaria, p.ej. Conectar).
    // "outline": borde + texto del color, fondo transparente que se tiñe
    // sutilmente al pasar el mouse (accion secundaria/destructiva).
    property string variant: "filled"
    readonly property bool filled: variant === "filled"

    signal clicked

    implicitWidth: label.implicitWidth + 18 * uiScale
    implicitHeight: 22 * uiScale

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.filled ? (mouseArea.containsMouse ? Qt.lighter(root.tint, 1.15) : root.tint) : (mouseArea.containsMouse ? Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.18) : "transparent")
        // Nota: Qt.lighter(color, factor) toma factor como escala normal
        // (1.0 = igual, >1.0 = mas claro) en QML/Qt6 -- a diferencia de la
        // API C++ de QColor que usa un entero base-100. Verificado con las
        // demas instancias de Qt.lighter/Qt.darker ya usadas en este repo
        // (Volume.qml, Backlight.qml), todas con valores tipo 1.4/2.2/0.55.
        border.width: root.filled ? 0 : 1
        border.color: root.tint

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.filled ? Colors.textDark : root.tint
        font.family: Colors.fontFamily
        font.pixelSize: 11 * root.uiScale
        font.bold: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
