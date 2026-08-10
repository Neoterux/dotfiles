import QtQuick
import QtQuick.Layouts

// Bloque de color reutilizable: es lo que en waybar era cada
// `#modulo { background: ...; border-radius: 10px; padding: ...; }`.
// Cualquier item declarado como hijo directo de un Pill{} se ubica
// automaticamente en el RowLayout interno (ver `default property alias`).
Rectangle {
    id: root

    default property alias content: layout.data
    property color bg: "#161320"
    property color fg: "#ebdbb2"
    property bool interactive: false
    property real hPadding: 9 * uiScale
    // Factor de escala general del pill (texto, alto, padding). Se puede
    // pisar por instancia -- p.ej. `Volume { uiScale: 0.85 }` -- y Bar.qml
    // lo reenvia a todos los modulos para poder variarlo por monitor
    // (ver shell.qml). Nota: esto tiene que entrar en el alto de la barra
    // (30*uiScale, ver shell.qml) -- si se agranda mucho un Pill se corta
    // contra el borde de la superficie de la PanelWindow.
    property real uiScale: 1.0
    // Tamaño de fuente sugerido para el Text interno de cada modulo.
    readonly property int fontPixelSize: Math.round(12 * uiScale)

    property bool hoverable: false
    readonly property bool hovered: hoverArea.containsMouse

    signal leftClicked
    signal rightClicked
    signal wheelUp
    signal wheelDown
    signal entered
    signal exited

    radius: 9 * uiScale
    color: bg
    implicitHeight: 24 * uiScale
    implicitWidth: layout.implicitWidth + hPadding * 2

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 5 * root.uiScale
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        enabled: root.interactive || root.hoverable
        hoverEnabled: root.hoverable
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.leftClicked();
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.wheelUp();
            else if (wheel.angleDelta.y < 0)
                root.wheelDown();
        }
        onEntered: root.entered()
        onExited: root.exited()
    }
}
