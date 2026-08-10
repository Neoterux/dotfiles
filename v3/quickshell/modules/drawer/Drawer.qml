import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"

// Drawer reutilizable (mismo nombre que usa caelestia-dots/shell para este
// concepto), anclado a un item de la barra (el pill que lo abre). Pensado
// para engancharle contenido con la propiedad default, p.ej.:
//
//   Drawer {
//       anchorItem: root
//       panelWindow: root.panelWindow
//       uiScale: root.uiScale
//       shown: root.expanded
//       Calendar { }
//   }
//
// Se probaron varias vueltas para un efecto "contracurva" en el hueco entre
// la barra y el popup (conector con esquinas mixtas, bulto hacia afuera,
// etc.) y ninguna termino pareciendose al de caelestia real -- ese usa un
// plugin C++ propio (SDF/metaballs) que no es replicable solo con QML/JS.
// Se descarto: la tarjeta es simplemente redondeada, sin nada raro en el
// hueco. Mas vale simple y prolijo que una imitacion fallida.
//
// Notas de las vueltas que hubo que dar para que esto renderice:
//  - `parentWindow` esta deprecado a favor de `anchor.window`.
//  - El `adjustment` por defecto de PopupAnchor (probablemente incluye
//    resize automatico) termina colapsando el popup contra los limites
//    de la superficie de la barra, que es angosta -- visualmente el popup
//    "existe" (visible=true, tamaño correcto por QML) pero no se ve un
//    pixel en pantalla. `PopupAdjustment.Slide` evita ese colapso y ademas
//    lo desliza para que no se corte contra el borde de la pantalla
//    (importante para el reloj, que es el ultimo pill a la derecha).
//  - Setear `anchor.item`/`visible:true` ANTES de que ese item este
//    realmente adjunto a una ventana crashea Quickshell (segfault en
//    QQuickItem::window()). No pasa en uso real (el click siempre ocurre
//    bastante despues del arranque), pero por eso `expanded` arranca en
//    `false` en Clock/Volume en vez de partir ya abierto.
PopupWindow {
    id: root

    required property Item anchorItem
    required property var panelWindow
    // Mismo factor que usa la barra de este monitor (ver shell.qml/Bar.qml)
    // -- sin esto el contenido de los drawers queda con tamaño fijo sin
    // importar el monitor en el que se abran.
    property real uiScale: 1.0
    // Lo que antes era `visible` pasado directo por el que abre el drawer.
    // Ahora es indirecto: al cerrar, `visible` real se mantiene un rato
    // mas mientras corre `closeAnim`, para que no desaparezca de un tiron
    // (antes solo la apertura estaba animada, el cierre era instantaneo).
    property bool shown: false

    anchor.window: panelWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    anchor.margins.top: Math.round(8 * uiScale)

    readonly property real pad: 20 * uiScale

    implicitWidth: inner.childrenRect.width + pad * 2
    implicitHeight: inner.childrenRect.height + pad * 2
    color: "transparent"
    visible: shown || closeAnim.running

    default property alias content: inner.data

    // Para dropdowns por hover (ver Clock.qml): el que abre el popup
    // necesita saber si el mouse sigue DENTRO del popup para no cerrarlo
    // apenas el cursor sale del pill de la barra camino al contenido.
    readonly property bool hovered: hoverTracker.containsMouse

    // NOTA: se intento agregar `grabFocus` aca para el buscador del
    // launcher, pero un PopupWindow (xdg-popup) con grabFocus:true no
    // renderiza nada -- falla en silencio, sin error en el log. El
    // launcher usa su propia ventana (LauncherPanel.qml, un PanelWindow
    // con `focusable`) en vez de este componente, justamente por eso.

    signal opened

    onShownChanged: {
        if (shown) {
            closeAnim.stop();
            openAnim.restart();
            contentAnim.restart();
        } else {
            openAnim.stop();
            contentAnim.stop();
            closeAnim.restart();
        }
    }

    // Tarjeta principal: esquinas redondeadas normales, sin borde -- el
    // look es el vidrio esmerilado (blur de Hyprland via layer_rule) + la
    // sombra.
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18 * root.uiScale
        color: Colors.bg
        transformOrigin: Item.Top
        opacity: 0
        scale: 0.94
        layer.enabled: true

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 0.95; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        // Simetrico al de apertura pero mas corto -- cerrar debe sentirse
        // rapido, no como un rebobinado. Mientras corre, `visible` de arriba
        // sigue en true (ver el binding), asi que el popup se ve encogerse
        // y desvanecerse en vez de desaparecer de un frame a otro.
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "scale"; to: 0.94; duration: 130; easing.type: Easing.InCubic }
            NumberAnimation { target: inner; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InCubic }
        }
    }

    MultiEffect {
        anchors.fill: card
        source: card
        z: card.z - 1
        opacity: card.opacity
        shadowEnabled: true
        shadowColor: "#80000000"
        shadowBlur: 0.6
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
        blurMax: 24
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.pad
        opacity: 0

        SequentialAnimation {
            id: contentAnim
            PauseAnimation { duration: 110 }
            NumberAnimation { target: inner; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        }
    }

    // Capa transparente ENCIMA de todo, solo para trackear hover: no
    // acepta botones (`acceptedButtons: Qt.NoButton`) y propaga el resto
    // de los eventos, asi que no interfiere con los clicks del contenido
    // de abajo (calendario, tabs, botones de media, etc.).
    MouseArea {
        id: hoverTracker
        anchors.fill: card
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
    }
}
