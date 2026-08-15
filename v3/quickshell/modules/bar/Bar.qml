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

    // Padding interno de los grupos de la derecha. El vertical es bien
    // chico: el contenido (IconButton, 24*uiScale) ya esta ajustado para
    // entrar en el alto de la barra con poco margen -- si el grupo se
    // agranda mucho se corta contra el borde de la superficie de la
    // PanelWindow (mismo limite que IconButton.qml).
    readonly property real groupHPad: 8 * uiScale
    readonly property real groupVPad: 1 * uiScale

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

    // Derecha: DOS grupos separados, no uno solo -- los applets de la
    // bandeja (apps de terceros, van y vienen) no son lo mismo que las
    // herramientas fijas de la barra, y mezclarlos en un unico pill los
    // hacia leer como una sola lista. El de la bandeja lleva el tinte del
    // pill de Workspaces (con Colors.bgTranslucent era indistinguible del
    // fondo de la barra).
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 10 * root.uiScale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * root.uiScale

        Rectangle {
            id: trayContainer
            // Sin applets no hay nada que agrupar: un pill vacio flotando
            // en la barra se ve como un bug.
            visible: trayRow.implicitWidth > 0
            Layout.preferredWidth: trayRow.implicitWidth + root.groupHPad * 2
            Layout.preferredHeight: trayRow.implicitHeight + root.groupVPad * 2
            radius: 10 * root.uiScale
            color: Colors.workspaceActiveBgTranslucent

            SystemTrayRow {
                id: trayRow
                anchors.centerIn: parent
                uiScale: root.uiScale
                panelWindow: root.panelWindow
            }
        }

        Rectangle {
            id: toolsContainer
            Layout.preferredWidth: toolsRow.implicitWidth + root.groupHPad * 2
            Layout.preferredHeight: toolsRow.implicitHeight + root.groupVPad * 2
            radius: 10 * root.uiScale
            color: Colors.bgTranslucent

            RowLayout {
                id: toolsRow
                anchors.centerIn: parent
                spacing: 2 * root.uiScale

                NetworkStatus { uiScale: root.uiScale }
                BluetoothButton { uiScale: root.uiScale; panelWindow: root.panelWindow }
                Terminal { uiScale: root.uiScale }
                Processes { uiScale: root.uiScale }
                PowerMenu { uiScale: root.uiScale; panelWindow: root.panelWindow }
            }
        }
    }
}
