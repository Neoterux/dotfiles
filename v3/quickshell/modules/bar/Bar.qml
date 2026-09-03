import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../theme"
import "../tray"
import "../drawer"

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

    // Interruptor del unico efecto que anima solo (ver el ShaderEffect
    // `sheen` mas abajo). Se apaga desde shell.qml si molesta o si hace
    // falta bajar el consumo.
    property bool sheenEnabled: true

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

    // La mitad del contorno que le toca a la barra cuando hay un drawer
    // abierto (shaders/bar_edge.frag): la linea del filo de abajo con un
    // hueco justo del ancho del drawer, para que el contorno del drawer
    // la continue y las dos piezas se lean como una sola.
    //
    // Solo la dibuja la barra del monitor donde esta el drawer abierto:
    // DrawerLink.window desempata (ver modules/drawer/DrawerLink.qml).
    ShaderEffect {
        id: barEdge
        anchors.fill: barBg
        visible: DrawerLink.window === root.panelWindow && DrawerLink.reveal > 0.001
        opacity: DrawerLink.reveal
        fragmentShader: Qt.resolvedUrl("../../shaders/bar_edge.frag.qsb")
        blending: true

        property vector2d size: Qt.vector2d(width, height)
        property real lineWidth: Math.max(1, Math.round(1.2 * root.uiScale))
        property real gapStart: DrawerLink.x + DrawerLink.join
        property real gapEnd: DrawerLink.x + DrawerLink.width - DrawerLink.join
        // Cuanto se estira la linea a los costados del drawer antes de
        // desaparecer. Cruzar la barra entera se veia como una regla
        // pegada abajo; asi parece el contorno del drawer derramandose.
        property real falloff: 260 * root.uiScale
        property color borderColor: Colors.accent
    }

    // Aurora lenta sobre el fondo de la barra (shaders/bar_sheen.frag).
    // Va declarada despues de `barBg` y antes de los modulos: mismo z, y
    // entre hermanos con el mismo z QtQuick pinta en orden de
    // declaracion, asi que queda sobre el fondo y debajo de todo el
    // contenido.
    //
    // Es el UNICO shader del shell que anima en reposo. Si algun dia la
    // barra tiene que costar cero, esto es lo primero que se apaga:
    // `sheenEnabled: false` y no queda nada corriendo.
    // El reloj y los colores salen del singleton theme/Sheen.qml, no de
    // aca: los drawers continuan esta misma onda en su propia superficie
    // y necesitan leer exactamente el mismo tiempo (ver Sheen.qml).
    ShaderEffect {
        id: sheen
        anchors.fill: barBg
        visible: root.sheenEnabled && Sheen.enabled
        fragmentShader: Qt.resolvedUrl("../../shaders/bar_sheen.frag.qsb")
        blending: true

        property real time: Sheen.time
        property real intensity: Sheen.intensity
        property color tintA: Sheen.tintA
        property color tintB: Sheen.tintB
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
        WorkspaceLayout { uiScale: root.uiScale; panelWindow: root.panelWindow }
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

                NetworkStatus { id: networkStatus; uiScale: root.uiScale; panelWindow: root.panelWindow }
                BluetoothButton { id: bluetoothButton; uiScale: root.uiScale; panelWindow: root.panelWindow }
                NotificationCenter { id: notificationCenter; uiScale: root.uiScale; panelWindow: root.panelWindow }
                Terminal { uiScale: root.uiScale }
                Processes { uiScale: root.uiScale }
                PowerMenu { id: powerMenu; uiScale: root.uiScale; panelWindow: root.panelWindow }
            }
        }
    }

    // Los cuatro botones de arriba con drawer (red, bluetooth,
    // notificaciones, power) estan muy pegados entre si en la barra --
    // sin esto, abrir uno mientras otro ya esta abierto deja los dos
    // popups superpuestos. Cada uno sigue dueño de su propio `expanded`;
    // esto solo lo apaga desde afuera apenas otro se prende, no hace
    // falta tocar NetworkStatus/BluetoothButton/NotificationCenter/
    // PowerMenu para esto.
    readonly property var drawerOwners: [networkStatus, bluetoothButton, notificationCenter, powerMenu]

    Connections {
        target: networkStatus
        function onExpandedChanged() {
            if (networkStatus.expanded)
                root.closeOtherDrawers(networkStatus);
        }
    }

    Connections {
        target: bluetoothButton
        function onExpandedChanged() {
            if (bluetoothButton.expanded)
                root.closeOtherDrawers(bluetoothButton);
        }
    }

    Connections {
        target: notificationCenter
        function onExpandedChanged() {
            if (notificationCenter.expanded)
                root.closeOtherDrawers(notificationCenter);
        }
    }

    Connections {
        target: powerMenu
        function onExpandedChanged() {
            if (powerMenu.expanded)
                root.closeOtherDrawers(powerMenu);
        }
    }

    function closeOtherDrawers(keepOpen) {
        for (const owner of root.drawerOwners) {
            if (owner !== keepOpen)
                owner.expanded = false;
        }
    }
}
