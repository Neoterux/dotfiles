import QtQuick
import Quickshell
import Quickshell.Hyprland
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
// La tarjeta la dibuja un fragment shader (shaders/drawer_card.frag): es
// una forma SDF con "contracurva" -- dos filetes concavos arriba que la
// abren hacia los costados hasta fundirla con la barra -- y su propio
// contorno. La barra dibuja la otra mitad de ese contorno en su propia
// superficie (shaders/bar_edge.frag), dejando un hueco del ancho exacto
// del popup, y las dos mitades empalman: leidas juntas parecen un unico
// contorno alrededor de barra + drawer.
//
// (Historico: este archivo decia que la contracurva se habia probado y
// descartado por irreproducible fuera de un plugin C++. Era cierto
// mientras se intentara componiendo Rectangle/Canvas; con un shader es
// media docena de lineas.)
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
    // Cerrar al clickear afuera. Opt-in y no por defecto: los drawers que
    // se abren por hover (el del reloj) no lo quieren -- un grab de
    // entrada mientras el mouse solo esta pasando por encima se comeria
    // clicks que no son para el drawer.
    property bool dismissOnClickOutside: false

    // Abrir por hover. `hoverSource` es el item de la barra que lo abre
    // (Pill o IconButton: los dos exponen `hovered`). El drawer se
    // considera "querido" mientras el mouse este sobre ese item O sobre
    // el propio drawer, con un margen de `hoverCloseDelay` para poder
    // cruzar de uno al otro sin que se cierre en el camino.
    //
    // Vive aca y no en cada modulo para no repetir el puente cinco veces
    // -- era logica copiada a mano en Clock.qml, ahora la usan todos.
    property bool hoverOpen: false
    property Item hoverSource: null
    property int hoverCloseDelay: 160
    // Traba para que el hover NO cierre el drawer aunque el mouse se haya
    // ido. Hace falta con cualquier control de arrastre adentro (el
    // Slider del volumen es el caso): al arrastrar, el MouseArea del
    // control se queda con el grab del puntero, asi que el mouse puede
    // salir de la superficie del popup sin soltar -- `hovered` se cae, el
    // timer corre y el drawer se cierra en plena arrastrada, dejando el
    // volumen donde haya quedado. Se ata al `pressed` del control.
    property bool hoverHold: false

    readonly property bool hoverWanted: root.hoverOpen && (root.hoverHold || (root.hoverSource && root.hoverSource.hovered) || root.hovered)

    signal openRequested
    signal closeRequested

    // Pill NO trackea el mouse por defecto: su MouseArea lleva
    // `hoverEnabled: root.hoverable`, y `hoverable` arranca en false. Un
    // Pill que solo declare `interactive: true` recibe clicks pero su
    // `containsMouse` no se prende NUNCA, asi que `hovered` queda clavado
    // en false y el puente de abajo no se entera de nada.
    //
    // Eso no da ningun error -- la property existe y devuelve un bool
    // perfectamente valido -- asi que un drawer con `hoverOpen: true`
    // sobre un Pill sin `hoverable` carga limpio y simplemente no abre.
    // Fue exactamente el bug de Volume/WorkspaceLayout. Se prende desde
    // aca para que pedir `hoverOpen` alcance y no haya que acordarse de
    // una segunda property en cada modulo.
    //
    // El guard es porque IconButton no tiene `hoverable` (su MouseArea ya
    // trackea siempre): asignar una property inexistente desde JS tira.
    function armHoverSource() {
        if (!root.hoverOpen || !root.hoverSource)
            return;
        if (root.hoverSource.hoverable !== undefined)
            root.hoverSource.hoverable = true;
    }

    Component.onCompleted: root.armHoverSource()
    onHoverSourceChanged: root.armHoverSource()
    onHoverOpenChanged: root.armHoverSource()

    onHoverWantedChanged: {
        if (root.hoverWanted) {
            hoverCloseTimer.stop();
            root.openRequested();
        } else {
            hoverCloseTimer.restart();
        }
    }

    Timer {
        id: hoverCloseTimer
        interval: root.hoverCloseDelay
        onTriggered: root.closeRequested()
    }

    signal dismissed

    anchor.window: panelWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    // OJO: `anchor.margins.top` NO se aplica. El popup queda pegado al
    // filo de abajo del ANCLA (el pill), y ese pill flota unos px por
    // encima del filo de abajo de la barra (24*uiScale de alto dentro de
    // una barra de 30*uiScale). Medido en pantalla: con `margins.top`
    // calculando 3 (y devolviendo 3 al leerlo), la superficie igual
    // arrancaba en el filo del pill, 3px MAS ARRIBA de donde termina la
    // barra -- o sea que el drawer se montaba sobre los ultimos px de la
    // barra y su contracurva empezaba 3px demasiado arriba. Eso era lo
    // que hacia que los dos contornos se vieran corridos. Es la misma
    // familia que la nota vieja de "margenes negativos en PopupWindow no
    // funcionan": aca tampoco.
    //
    // Como el margen no sirve, se compensa PUERTAS ADENTRO: la tarjeta se
    // dibuja `barOverlap` px mas abajo dentro de su propia superficie,
    // que es exactamente lo que sobra. Asi su filo de arriba cae justo
    // donde termina la barra.
    readonly property real barOverlap: {
        if (!root.anchorItem || !root.panelWindow)
            return 0;
        const bottom = root.anchorItem.mapToItem(null, 0, root.anchorItem.height).y;
        return Math.max(0, Math.round(root.panelWindow.height - bottom));
    }

    readonly property real pad: 20 * uiScale
    // Lado del filete concavo que une la tarjeta con la barra. Tambien es
    // cuanto se ensancha el popup: los filetes viven en ese margen, a los
    // costados del cuerpo (ver shaders/drawer_card.frag).
    //
    // Empezo en 16 y no se veia: contra un fondo translucido, una curva
    // de 16px sin nada que la recorra no se lee como curva. Se sube a 26
    // Y se le dibuja el contorno -- las dos cosas juntas, subir el numero
    // solo no alcanzaba.
    readonly property real wing: 26 * uiScale
    readonly property real borderWidth: Math.max(1, Math.round(1.2 * uiScale))
    // Cuanto se mete la linea de la barra POR ENCIMA del ancho del
    // drawer. La forma del drawer ya llega tangente a la barra, asi que
    // geometricamente se tocan en un punto; pero dos trazos que terminan
    // justo en el mismo pixel, cada uno con su antialias y en superficies
    // distintas, dejan un pelito de aire que se lee como "no estan
    // unidos". Con un par de px de solape la union queda solida.
    readonly property real joinOverlap: Math.max(2, 2 * uiScale)

    // 0 = cerrado, 1 = abierto. Maneja el "desenrollado" hacia abajo: la
    // tarjeta crece desde la barra en vez de escalar desde el centro.
    // Ademas de verse mejor para algo que se supone pegado a la barra,
    // esto arregla de raiz un problema del scale: al escalar, el ancho
    // renderizado no coincidia con el ancho logico, y el hueco que la
    // barra le deja al contorno (ver bar_edge.frag) bailaba durante toda
    // la animacion. Desenrollando, el ancho es constante desde el frame 1.
    property real reveal: 0

    // Posicion horizontal del popup PREDICHA, para que la barra sepa
    // donde dejar el hueco. Hay que predecirla porque PopupWindow no
    // expone la suya (`x`/`y` dan undefined -- verificado). La regla del
    // compositor, medida en pantalla con un popup magenta: centrado en el
    // ancla, y despues acotado a la pantalla (PopupAdjustment.Slide).
    readonly property real predictedX: {
        if (!root.anchorItem || !root.panelWindow)
            return 0;
        const center = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, 0).x;
        const w = root.implicitWidth;
        return Math.max(0, Math.min(root.panelWindow.width - w, center - w / 2));
    }

    // Publicar la geometria mientras este abierto. Al cerrarse solo se
    // borra si el que figura es este: si no, un drawer que se cierra
    // justo cuando otro se abre le pisaria los datos al nuevo.
    function publishGeometry() {
        if (root.shown) {
            DrawerLink.window = root.panelWindow;
            DrawerLink.x = root.predictedX;
            DrawerLink.width = root.implicitWidth;
            DrawerLink.join = root.joinOverlap;
            DrawerLink.reveal = root.reveal;
        } else if (DrawerLink.window === root.panelWindow && !root.visible) {
            DrawerLink.window = null;
            DrawerLink.reveal = 0;
        }
    }

    onRevealChanged: root.publishGeometry()
    onVisibleChanged: root.publishGeometry()

    implicitWidth: inner.childrenRect.width + pad * 2 + wing * 2
    implicitHeight: inner.childrenRect.height + pad * 2 + barOverlap
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

    // Un xdg-popup no se entera de NADA que pase fuera de su superficie, y
    // el `grabFocus` que serviria para eso no renderiza (ver nota de mas
    // arriba). HyprlandFocusGrab le pide al compositor el grab de entrada
    // para esta ventana: los clicks adentro siguen funcionando igual y el
    // primero que caiga afuera dispara `cleared` en vez de perderse.
    // El grab tambien se activa con el drawer abierto por hover, pero
    // SOLO mientras el mouse esta adentro del popup. Ahi no puede comerse
    // un click ajeno (un click con el cursor adentro del drawer es para
    // el drawer), y es lo que le da teclado a la ventana para que ESC
    // pueda cerrarla -- un PopupWindow por si solo no recibe teclas.
    //
    // No se uso un bind global de Hyprland para ESC a proposito: uno fijo
    // se comeria ESC en todas las apps, y uno que se registre y se borre
    // por cada apertura significaria lanzar hyprctl cada vez que el mouse
    // pasa por la barra.
    HyprlandFocusGrab {
        active: (root.dismissOnClickOutside && root.shown) || (root.hoverOpen && root.shown && root.hovered)
        windows: [root]
        onCleared: root.dismissed()
    }

    signal escapePressed

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

    // Tarjeta principal, dibujada por SDF (shaders/drawer_card.frag):
    // redondeada abajo y con "contracurva" arriba -- dos filetes concavos
    // que la abren hacia los costados hasta fundirse con la barra.
    //
    // Esto es lo que en su momento se dio por imposible (ver v3/CLAUDE.md):
    // con Rectangles/Canvas no salia porque la union de un cuerpo convexo
    // con dos recortes concavos no se compone con formas, se resuelve con
    // distancias con signo. El plugin C++ de caelestia hace exactamente
    // esto; en QML se puede desde que ShaderEffect existe.
    //
    // El resto del look no cambia: sin borde, vidrio esmerilado (blur de
    // Hyprland via layer_rule) + sombra.
    ShaderEffect {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        // Arranca `barOverlap` px mas abajo: esos px de la superficie
        // caen ENCIMA de la barra (ver la nota de arriba) y tienen que
        // quedar transparentes para que el filo de la tarjeta coincida
        // con el filo de la barra.
        y: root.barOverlap
        // Se desenrolla desde la barra. El piso en `wing` evita que el
        // SDF quede degenerado (filetes y radio mas grandes que la propia
        // tarjeta) en los primeros frames; a esa altura la opacidad
        // todavia es 0 igual.
        height: Math.max(root.wing, (parent.height - root.barOverlap) * root.reveal)

        fragmentShader: Qt.resolvedUrl("../../shaders/drawer_card.frag.qsb")
        blending: true

        property vector2d size: Qt.vector2d(width, height)
        // El radio no puede pasar de media tarjeta o las esquinas de
        // abajo se cruzan mientras se desenrolla.
        property real radius: Math.min(18 * root.uiScale, height / 2)
        property real wing: root.wing
        property real borderWidth: root.borderWidth
        property real sweep: 0

        // Vidrio esmerilado: el relleno tiene que ser TRANSLUCIDO para
        // que se vea el desenfoque que pone el compositor detras (el
        // layer_rule `blur` de Hyprland alcanza tambien a los popups de
        // la barra, ver la seccion de integracion con Hyprland). Con
        // `Colors.bg` opaco, el blur estaba ahi abajo pero tapado, y la
        // tarjeta se leia como un panel plano.
        property color fill: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.78)
        property color borderColor: Colors.accent
        property real rimWidth: Math.max(1, 1.5 * root.uiScale)
        property real rimFade: 150 * root.uiScale
        property real rimStrength: 0.20
        property color rimColor: Colors.fg

        // Continuacion de la aurora de la barra. `sheenOriginX` es la
        // posicion del popup DENTRO de la barra: con eso el shader evalua
        // la onda en coordenadas absolutas y el degrade cruza la juntura
        // sin cortarse (ver theme/Sheen.qml y drawer_card.frag).
        property real sheenTime: Sheen.enabled ? Sheen.time : 0
        property real sheenIntensity: Sheen.enabled ? Sheen.intensity : 0
        property real sheenOriginX: root.predictedX
        property real sheenSpanX: root.panelWindow ? root.panelWindow.width : 1920
        property real sheenFade: 120 * root.uiScale
        property color tintA: Sheen.tintA
        property color tintB: Sheen.tintB

        opacity: 0
        // Sin `layer.enabled`: solo estaba para que el MultiEffect de la
        // sombra pudiera usar la tarjeta como textura, y ese MultiEffect
        // ya no esta (ver arriba). Dejarlo costaba una textura intermedia
        // y un draw extra por frame para nada.

        // Curvas "emphasized" de Material 3 (decelerate al abrir,
        // accelerate al cerrar) en vez de las Easing.* de Qt: arrancan
        // mucho mas rapido y frenan mucho mas largo, que es lo que da la
        // sensacion de suave sin sentirse lento. Son las curvas publicas
        // de la spec de Material, NO codigo sacado de caelestia-dots ni
        // de ningun otro shell -- de ahi no se copio nada.
        readonly property var easeOut: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
        readonly property var easeIn: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0.95
                duration: 160
                easing.type: Easing.Bezier
                easing.bezierCurve: card.easeOut
            }
            NumberAnimation {
                target: root
                property: "reveal"
                to: 1
                duration: 300
                easing.type: Easing.Bezier
                easing.bezierCurve: card.easeOut
            }
            // Destello que recorre el frente del desenrollado y se apaga
            // solo. Es un one-shot: no queda nada animando con el drawer
            // abierto.
            SequentialAnimation {
                NumberAnimation { target: card; property: "sweep"; to: 1; duration: 120 }
                NumberAnimation { target: card; property: "sweep"; to: 0; duration: 320; easing.type: Easing.InCubic }
            }
        }

        // Mas corto que la apertura -- cerrar debe sentirse instantaneo,
        // no como un rebobinado. Mientras corre, `visible` de arriba sigue
        // en true (ver el binding), asi que el popup se ve enrollarse en
        // vez de desaparecer de un frame a otro.
        ParallelAnimation {
            id: closeAnim
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: 130
                easing.type: Easing.Bezier
                easing.bezierCurve: card.easeIn
            }
            NumberAnimation {
                target: root
                property: "reveal"
                to: 0
                duration: 170
                easing.type: Easing.Bezier
                easing.bezierCurve: card.easeIn
            }
            NumberAnimation { target: inner; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InCubic }
        }
    }

    // NO va un MultiEffect de sombra aca. Dibujaba una SEGUNDA copia de
    // la tarjeta (MultiEffect pinta la fuente ademas de la sombra) y, con
    // `autoPaddingEnabled` en true, corrida ~21px: con la tarjeta lisa de
    // antes no se notaba, pero apenas la tarjeta tuvo contorno aparecio
    // como un doble borde fantasma. Y la sombra en si nunca se vio: el
    // popup mide exactamente lo que la tarjeta, asi que el desenfoque
    // caia siempre fuera de la superficie y quedaba recortado. O sea que
    // solo estaba pagando un layer y un draw de mas para producir un
    // artefacto. La profundidad la dan el contorno y el blur del
    // compositor (layer_rule de Hyprland).

    Item {
        id: inner
        // `focus` + Keys para que ESC cierre el drawer. Solo llega tecla
        // mientras el HyprlandFocusGrab de arriba esta activo (o sea, con
        // el mouse adentro del drawer).
        focus: true
        Keys.onEscapePressed: event => {
            root.escapePressed();
            event.accepted = true;
        }

        anchors.fill: parent
        anchors.margins: root.pad
        // Los costados llevan ademas el ancho del filete: ese margen es
        // area de la contracurva, no del contenido.
        anchors.leftMargin: root.pad + root.wing
        anchors.rightMargin: root.pad + root.wing
        anchors.topMargin: root.pad + root.barOverlap
        opacity: 0

        // Entra apenas el desenrollado paso la mitad: antes se esperaba
        // 110ms quieto y recien ahi arrancaba un fade de 140, o sea un
        // cuarto de segundo hasta poder leer nada. Ahora el contenido
        // esta entero a los ~190ms.
        SequentialAnimation {
            id: contentAnim
            PauseAnimation { duration: 70 }
            NumberAnimation {
                target: inner
                property: "opacity"
                to: 1
                duration: 190
                easing.type: Easing.Bezier
                easing.bezierCurve: card.easeOut
            }
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
