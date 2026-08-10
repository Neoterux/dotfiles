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

    // Bridging: se muestra mientras el mouse este sobre el pill O sobre
    // el popup, con un margen de "closeDelay" antes de cerrarse del
    // todo -- asi da tiempo a mover el cursor de uno a otro.
    readonly property bool wantsOpen: root.hovered || dashPopup.hovered

    onWantsOpenChanged: {
        if (wantsOpen) {
            closeTimer.stop();
            root.expanded = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.expanded = false
    }

    Drawer {
        id: dashPopup
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        Dashboard { uiScale: root.uiScale }
    }
}
