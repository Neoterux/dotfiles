import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../theme"
import "../tray"

// Layout general de la barra: izquierda / centro / derecha. Todos los
// componentes de esta carpeta viven en la misma carpeta, asi que QML los
// resuelve sin necesidad de un import extra; la bandeja del sistema vive
// aparte (../tray) porque es su propio subsistema.
Item {
    id: root

    // Factor de escala para toda la barra de este monitor. shell.qml le
    // pasa un valor distinto a cada PanelWindow segun el monitor.
    property real uiScale: 1.0
    // PanelWindow dueña de esta barra: los modulos con dropdown (Clock,
    // Volume) la necesitan para poder anclarse correctamente.
    required property var panelWindow

    // Fondo de la barra: a todo el ancho, sin borde ni esquinas
    // redondeadas (antes era un pill flotante centrado; ahora ocupa todo
    // el espacio, pegado a los bordes de la pantalla).
    Rectangle {
        id: barBg
        anchors.fill: parent
        color: Colors.bgTranslucent
        opacity: 0.95
    }

    MultiEffect {
        anchors.fill: barBg
        source: barBg
        z: barBg.z - 1
        shadowEnabled: true
        shadowColor: "#66000000"
        shadowBlur: 0.5
        shadowVerticalOffset: 2
        blurMax: 16
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14 * root.uiScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * root.uiScale

        Launcher { uiScale: root.uiScale; panelWindow: root.panelWindow }
        Backlight { uiScale: root.uiScale }
        Volume { uiScale: root.uiScale; panelWindow: root.panelWindow }
        Workspaces { uiScale: root.uiScale }
    }

    Clock {
        uiScale: root.uiScale
        panelWindow: root.panelWindow
        anchors.centerIn: parent
    }

    // Antes estos flotaban directo sobre el fondo de la barra, sueltos.
    // Un solo contenedor glass (mismo estilo que el resto de la barra:
    // Colors.bgTranslucent + esquinas redondeadas) los agrupa como una
    // unidad visual, igual que Workspaces.qml ya hace con su propio pill.
    Rectangle {
        id: rightContainer
        anchors.right: parent.right
        anchors.rightMargin: 10 * root.uiScale
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: rightRow.implicitWidth + hPad * 2
        implicitHeight: rightRow.implicitHeight + vPad * 2
        radius: 10 * root.uiScale
        color: Colors.bgTranslucent

        readonly property real hPad: 8 * root.uiScale
        // Vertical bien chico: el contenido (IconButton, 26*uiScale) ya
        // esta ajustado para entrar en el alto de la barra con poco
        // margen -- si se agranda mucho se corta contra el borde de la
        // superficie de la PanelWindow (mismo limite que IconButton.qml).
        readonly property real vPad: 1 * root.uiScale

        RowLayout {
            id: rightRow
            anchors.centerIn: parent
            spacing: 2 * root.uiScale

            SystemTrayRow { uiScale: root.uiScale; panelWindow: root.panelWindow }
            NetworkStatus { uiScale: root.uiScale }
            BluetoothButton { uiScale: root.uiScale; panelWindow: root.panelWindow }
            Terminal { uiScale: root.uiScale }
            Processes { uiScale: root.uiScale }
            PowerMenu { uiScale: root.uiScale; panelWindow: root.panelWindow }
        }
    }
}
