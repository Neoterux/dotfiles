import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../../theme"
import "../bar"

// Una tarjeta de notificacion "toast" -- usada tanto por el popup
// (NotificationPopupWindow.qml, se autodestruye por su timer) como por
// el historial (NotificationCenter.qml, se queda hasta que la
// descartes). `dismissable` distingue el boton de cierre en cada caso:
// en el popup solo saca el toast de pantalla (sigue en el historial); en
// el historial, cierra la notificacion de verdad (avisa al que la mando).
Rectangle {
    id: root

    property real uiScale: 1.0
    required property var notification
    property bool isPopupContext: true

    readonly property color urgencyColor: notification.urgency === NotificationUrgency.Critical ? Colors.network : (notification.urgency === NotificationUrgency.Low ? Colors.fg : Colors.accent)

    // Icono: mismo criterio que el resto del repo (ver CLAUDE.md) --
    // `hasThemeIcon` ANTES de armar el source, `notification.image` (si
    // vino) tiene prioridad sobre el nombre de icono de la app.
    readonly property string resolvedIconSource: {
        if (notification.image)
            return notification.image;
        const n = notification.appIcon;
        return n && Quickshell.hasThemeIcon(n) ? Quickshell.iconPath(n) : "";
    }

    // La accion con id "default" es especial (spec de freedesktop): se
    // dispara al clickear la notificacion ENTERA, no un boton -- los
    // daemons que se portan bien (dunst, mako) no la muestran como chip
    // aparte. Sin este filtro, Claude Code (entre otras apps) manda esa
    // accion con texto vacio/no pensado para mostrarse, y se ve como un
    // chip vacio sin texto -- confirmado en vivo con la notificacion real
    // "Claude is waiting for your input".
    readonly property var visibleActions: notification.actions.filter(a => a.identifier !== "default" && a.text !== "")

    signal closeRequested

    // Entrada "materializandose" (shaders/dissolve.frag) en vez de un
    // fade plano. Solo para toasts: en el historial las tarjetas se crean
    // todas de golpe al abrir el drawer y verlas disolverse en bloque es
    // ruido, no efecto -- de ahi que `isPopupContext` (que hasta ahora era
    // decorativa) por fin decida algo.
    property real dissolveProgress: root.isPopupContext ? 0 : 1

    NumberAnimation {
        target: root
        property: "dissolveProgress"
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
        running: root.isPopupContext
    }

    // La capa existe solo mientras dura la animacion: al terminar se
    // apaga y no queda ni la textura intermedia ni el shader colgados de
    // una tarjeta que se va a quedar quieta varios segundos.
    layer.enabled: root.dissolveProgress < 1
    layer.effect: ShaderEffect {
        // `source` va declarada a mano a proposito: layer.effect asigna
        // la textura con setProperty() sobre el nombre de layer.samplerName,
        // y si la property no existe Qt crea una dinamica que el
        // ShaderEffect no mira -- el sampler queda vacio y la tarjeta sale
        // en negro.
        property var source
        property real progress: root.dissolveProgress
        property color sparkColor: root.urgencyColor
        fragmentShader: Qt.resolvedUrl("../../shaders/dissolve.frag.qsb")
    }

    implicitWidth: 320 * uiScale
    implicitHeight: content.implicitHeight + 20 * uiScale
    radius: 14 * uiScale
    color: Colors.bg
    opacity: 0.97
    border.width: 1
    border.color: Qt.rgba(urgencyColor.r, urgencyColor.g, urgencyColor.b, 0.35)

    // Click del medio en cualquier parte de la tarjeta = descartarla, lo
    // mismo que la X (convencion de dunst/mako/swaync). Va declarado ANTES
    // del contenido a proposito: el hit-test de QtQuick va del ultimo hijo
    // al primero, asi que esto queda por DEBAJO de la X y de los chips de
    // accion. Y como solo acepta el boton del medio, los clicks izquierdos
    // pasan de largo -- ni les roba los suyos a los chips, ni le corta el
    // arrastre al Flickable del historial.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.closeRequested()
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12 * root.uiScale
        spacing: 6 * root.uiScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.uiScale

            Rectangle {
                Layout.preferredWidth: 32 * root.uiScale
                Layout.preferredHeight: 32 * root.uiScale
                radius: 10 * root.uiScale
                color: Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.18)

                IconImage {
                    id: appIcon
                    anchors.centerIn: parent
                    implicitSize: 18 * root.uiScale
                    source: root.resolvedIconSource
                    visible: source !== "" && status === Image.Ready
                }

                Text {
                    visible: !appIcon.visible
                    anchors.centerIn: parent
                    text: "\u{f0f3}" // nf-fa-bell
                    color: root.urgencyColor
                    font.family: Colors.fontFamily
                    font.pixelSize: 14 * root.uiScale
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.uiScale

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.notification.summary
                    color: Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: 13 * root.uiScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.notification.appName !== ""
                    text: root.notification.appName
                    color: Colors.fg
                    opacity: 0.5
                    font.family: Colors.fontFamily
                    font.pixelSize: 10 * root.uiScale
                }
            }

            Text {
                text: "\u{f00d}" // nf-fa-times
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        Text {
            visible: root.notification.body !== ""
            Layout.fillWidth: true
            text: root.notification.body
            textFormat: Text.StyledText
            color: Colors.fg
            opacity: 0.8
            font.family: Colors.fontFamily
            font.pixelSize: 11 * root.uiScale
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        RowLayout {
            visible: root.visibleActions.length > 0
            Layout.fillWidth: true
            spacing: 8 * root.uiScale

            Repeater {
                model: root.visibleActions

                delegate: ActionChip {
                    required property var modelData
                    uiScale: root.uiScale
                    text: modelData.text
                    variant: "outline"
                    tint: root.urgencyColor
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
