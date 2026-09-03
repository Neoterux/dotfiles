import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../drawer"
import "../dashboard"

// Reloj centrado: "{hostname} | {fecha completa}". A diferencia de los
// demas modulos, el dashboard se abre con HOVER (no click), con un
// pequeño delay al salir para poder mover el mouse desde el pill hasta
// el popup sin que se cierre solo.
Pill {
    id: root
    bg: "transparent"
    fg: Colors.fg
    hoverable: true

    required property var panelWindow
    property bool expanded: false
    // FileView.text() carga async: llamarlo en un Component.onCompleted
    // (o incluso en un binding declarativo) puede evaluar antes de que
    // termine la lectura y quedarse pegado en "". La forma confiable es
    // escuchar la señal `loaded`/`textChanged` explicitamente.
    property string hostname: ""

    FileView {
        id: hostnameFile
        path: "/etc/hostname"
        onLoaded: root.hostname = text().trim()
        onTextChanged: root.hostname = text().trim()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: true
    }

    function cap1(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    Text {
        text: root.hostname + " | " + root.cap1(clock.date.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM")) + " - " + Qt.formatTime(clock.date, "HH:mm")
        color: root.fg
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize
        font.bold: true
    }

    // El puente hover->expanded (incluido el margen para cruzar del pill
    // al popup sin que se cierre) ya no vive aca: es `hoverOpen` en
    // Drawer.qml, que ahora usan todos los modulos con drawer.
    Drawer {
        id: dashPopup
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded
        hoverOpen: true
        hoverSource: root
        onOpenRequested: root.expanded = true
        onCloseRequested: root.expanded = false
        // ESC lo cierra sin tener que mover el mouse. No se vuelve a
        // abrir solo: el puente de hover dispara por CAMBIO de estado,
        // asi que hay que salir y volver a entrar.
        onEscapePressed: root.expanded = false

        Dashboard { uiScale: root.uiScale }
    }
}
