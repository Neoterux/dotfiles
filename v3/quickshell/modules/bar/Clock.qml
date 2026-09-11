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

        // El Dashboard NO se instancia hasta que el drawer se ve por
        // primera vez. Un PopupWindow oculto igual construye a sus hijos,
        // asi que antes las 5 tabs (su barra, el Loader de pagina y la
        // pagina activa con sus FileView/Timer) vivian desde el arranque
        // del shell y para siempre -- y por DOS, porque Bar.qml se
        // instancia una vez por monitor.
        //
        // Cuanto ahorra, medido en serio: ~12 MB. Y OJO con como se mide,
        // porque el primer numero que saque para esto (29 MB) era ruido.
        //
        // Comparar el RSS de DOS arranques distintos no sirve: entre
        // corridas de la MISMA config el RSS varia +-35 MB (los iconos de
        // bandeja que alcanzaron a conectarse por SNI, las ventanas
        // abiertas en cada workspace, cuando asigna Mesa). Con n=3 eager
        // vs lazy los rangos se pisan enteros y no se puede concluir nada.
        //
        // Lo que si mide: un solo proceso, cuatro tomas.
        //   reposo, sin abrirlo nunca ... 471 MB
        //   dashboard abierto ........... 483 MB   (+12)
        //   cerrado, retain corriendo ... 469 MB
        //   retain vencido .............. 467 MB   (vuelve por debajo)
        // O sea: cuesta ~12 MB mientras existe y esos 12 MB SE DEVUELVEN.
        //
        // Para perspectiva: el piso de Qt6+Mesa en este equipo es ~305 MB
        // (medido con un shell de dos PanelWindow y un Text). Nada de lo
        // que se haga en QML lo baja.
        //
        // `dashRetain` es para que no se reconstruya en cada hover: al
        // cerrar se mantiene vivo 20s mas, asi abrir/cerrar/abrir no paga
        // la construccion tres veces. Pasados los 20s se libera de verdad.
        // Un Timer no es Item, asi que no entra en `childrenRect` y no
        // afecta el tamaño del popup.
        Timer {
            id: dashRetain
            interval: 20000
            repeat: false
        }

        onVisibleChanged: {
            if (dashPopup.visible)
                dashRetain.stop();
            else
                dashRetain.restart();
        }

        Loader {
            active: dashPopup.visible || dashRetain.running
            // `Dashboard` adentro de un Component: sin esto el objeto se
            // crearia igual al cargar el QML y el Loader no serviria de
            // nada.
            sourceComponent: Component {
                Dashboard { uiScale: root.uiScale }
            }
        }
    }
}
