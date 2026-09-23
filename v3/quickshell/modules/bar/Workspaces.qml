import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import "../../theme"

// Equivalente a "hyprland/workspaces" de waybar, pero reactivo via la IPC
// nativa de Quickshell (Hyprland.workspaces) en vez de leer el socket a mano.
//
// Regla de que se muestra en cada pill (pedido explicito, no derivable del
// codigo): si el workspace no tiene ventanas Y no esta enfocado, un simple
// punto. Si tiene ventanas (sin importar si esta enfocado) muestra el
// icono de su app; si esta enfocado pero vacio, o el icono no se pudo
// resolver, cae al numero/nombre del workspace. El contenedor entero (no
// cada pill) se tiñe con el color de "workspace activo" bien translucido,
// como fondo glass compartido.
Pill {
    id: root
    bg: Colors.workspaceActiveBgTranslucent
    fg: Colors.fg
    hPadding: 6 * uiScale

    // Barra duena de este pill: hace falta para saber que scratchpad esta
    // abierto en ESTE monitor (el pill de cada monitor resalta el suyo).
    property var panelWindow: null
    readonly property var monitor: root.panelWindow ? Hyprland.monitorFor(root.panelWindow.screen) : null

    // Los workspaces especiales (scratchpads) se llaman "special:<nombre>"
    // -- crudo, ese string no entra en un circulo de 20px y se desborda
    // pisando los pills vecinos. Se separan del v-for normal y se dibujan
    // aparte: "special:magic" (el de SUPER + P) siempre, y cualquier otro
    // mientras exista.
    readonly property var specials: {
        const names = ["special:magic"];
        for (const w of Hyprland.workspaces.values) {
            if (w.name.indexOf("special:") === 0 && names.indexOf(w.name) < 0)
                names.push(w.name);
        }
        return names;
    }

    // El scratchpad abierto en este monitor NO es su `activeWorkspace`: va
    // en un slot aparte (`specialWorkspace` del IPC crudo). Abrirlo o
    // cerrarlo solo emite `activespecial`, asi que se re-listan los
    // monitores ahi (mismo truco que WorkspaceLayout.qml).
    readonly property string shownSpecial: {
        const ipc = root.monitor ? root.monitor.lastIpcObject : null;
        const sp = ipc ? ipc.specialWorkspace : null;
        return sp && sp.name ? String(sp.name) : "";
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2")
                Hyprland.refreshMonitors();
        }
    }

    readonly property var regular: Hyprland.workspaces.values.filter(w => w.name.indexOf("special:") !== 0);

    // Con la config en Lua, `hyprctl dispatch` evalua su argumento como Lua
    // (ver la nota en hypr/hyprland-neo/workspaces/init.lua): el string
    // clasico "togglespecialworkspace magic" falla en silencio. Mismo
    // patron que PowerMenu.qml.
    Process {
        id: specialProc
    }

    function specialDispatch(lua: string) {
        if (specialProc.running)
            return;
        specialProc.command = ["hyprctl", "dispatch", lua];
        specialProc.running = true;
    }

    // Un circulo por scratchpad. Borde de acento = tiene ventanas; relleno =
    // abierto en este monitor; apagado = vacio. Click izq muestra/oculta,
    // click der manda ahi la ventana activa. "magic" lleva su icono; los
    // demas, la inicial de su nombre.
    Repeater {
        model: root.specials

        delegate: Rectangle {
            id: sp
            required property string modelData
            readonly property string shortName: sp.modelData.substring(8)
            readonly property bool exists: Hyprland.workspaces.values.some(w => w.name === sp.modelData)
            readonly property bool shown: root.shownSpecial === sp.modelData

            width: 20 * root.uiScale
            height: 20 * root.uiScale
            radius: 8 * root.uiScale
            color: sp.shown ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.25) : "transparent"
            border.width: sp.exists ? 1 : 0
            border.color: Colors.accent
            opacity: sp.exists || sp.shown ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: sp.shortName === "magic" ? "\u{f0d0}" : sp.shortName.charAt(0).toUpperCase() // nf-fa-magic
                color: sp.exists ? Colors.accent : Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: root.fontPixelSize - 1
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    // Los nombres salen de Hyprland (sin comillas); igual se
                    // escapan porque entran en un string literal de Lua.
                    const name = sp.shortName.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
                    if (mouse.button === Qt.RightButton)
                        root.specialDispatch('hl.dsp.window.move({ workspace = "special:' + name + '" })');
                    else
                        root.specialDispatch('hl.dsp.workspace.toggle_special("' + name + '")');
                }
            }
        }
    }

    Repeater {
        model: root.regular

        delegate: Item {
            id: wsDelegate
            required property var modelData

            readonly property bool hasContent: wsDelegate.modelData.toplevels.values.length > 0
            // Preferir la ventana marcada "activated" dentro del
            // workspace (la que tendria foco si saltaras a el); si
            // ninguna, la primera de la lista.
            readonly property var focusedToplevel: {
                const wins = wsDelegate.modelData.toplevels.values;
                if (wins.length === 0)
                    return null;
                return wins.find(w => w.activated) || wins[0];
            }
            readonly property string appId: wsDelegate.focusedToplevel && wsDelegate.focusedToplevel.wayland ? wsDelegate.focusedToplevel.wayland.appId : ""
            // El appId de Wayland no siempre coincide con el nombre de
            // icono real (VSCode: appId "code-oss", icono
            // "com.visualstudio.code.oss") -- usar el appId directo como
            // nombre de icono resuelve "bien" (Quickshell.iconPath no
            // tira error) pero carga el placeholder "imagen rota" del
            // tema (cuadriculado magenta/negro) en vez de fallar, asi que
            // ni `status === Image.Ready` lo detecta. `hasThemeIcon`
            // confirma si el nombre existe de verdad ANTES de intentar
            // cargarlo, y DesktopEntries resuelve el nombre real del
            // .desktop cuando el appId no es directamente un icono.
            readonly property string resolvedIconName: {
                if (!wsDelegate.appId)
                    return "";
                const entry = DesktopEntries.byId(wsDelegate.appId) || DesktopEntries.heuristicLookup(wsDelegate.appId);
                const name = entry ? entry.icon : wsDelegate.appId;
                return Quickshell.hasThemeIcon(name) ? name : "";
            }
            readonly property bool showDetail: wsDelegate.modelData.focused || wsDelegate.hasContent

            width: 20 * root.uiScale
            height: 20 * root.uiScale

            // Cuanto se desborda el halo por fuera de la caja. El delegate
            // dejo de ser el Rectangle para poder dibujarlo: `box` sigue
            // con `clip: true` (recorta iconos/nombres largos) y un halo
            // hijo suyo quedaria cortado justo en el borde, que es
            // exactamente donde tiene que verse.
            readonly property real glowMargin: 9 * root.uiScale

            // Resplandor del workspace enfocado. Sin uniforms animados no
            // repinta salvo cuando cambia el foco, y con `visible` en
            // false ni siquiera llega al scene graph.
            ShaderEffect {
                anchors.centerIn: parent
                width: parent.width + wsDelegate.glowMargin * 2
                height: parent.height + wsDelegate.glowMargin * 2
                fragmentShader: Qt.resolvedUrl("../../shaders/glow.frag.qsb")
                blending: true

                property vector2d size: Qt.vector2d(width, height)
                property vector2d boxHalf: Qt.vector2d(wsDelegate.width * 0.5, wsDelegate.height * 0.5)
                property real radius: 8 * root.uiScale
                // `spread` bien por debajo del margen para que la
                // exponencial ya este casi apagada cuando la ventana del
                // shader la corta -- ver el comentario en glow.frag.
                property real spread: wsDelegate.glowMargin / 2.6
                property real cutoff: wsDelegate.glowMargin
                property real intensity: 0.55
                property color glowColor: Colors.accent

                opacity: wsDelegate.modelData.focused ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                id: box
                anchors.fill: parent
                radius: 8 * root.uiScale
                clip: true
                color: "transparent"
                border.width: wsDelegate.modelData.focused ? 1.5 : 0
                border.color: Colors.accent

                Behavior on border.width {
                    NumberAnimation { duration: 120 }
                }

                // vacio y sin foco: solo un punto
                Rectangle {
                    visible: !wsDelegate.showDetail
                    anchors.centerIn: parent
                    width: 6 * root.uiScale
                    height: 6 * root.uiScale
                    radius: width / 2
                    color: Colors.fg
                    opacity: 0.45
                }

                // con contenido: icono de la app (la que tenga foco dentro del
                // workspace, o la primera)
                IconImage {
                    id: icon
                    visible: wsDelegate.showDetail && wsDelegate.resolvedIconName !== "" && status === Image.Ready
                    anchors.centerIn: parent
                    implicitSize: 14 * root.uiScale
                    source: wsDelegate.resolvedIconName ? Quickshell.iconPath(wsDelegate.resolvedIconName) : ""
                }

                // fallback: enfocado pero vacio, o el icono no se pudo resolver
                Text {
                    visible: wsDelegate.showDetail && !icon.visible
                    anchors.centerIn: parent
                    text: wsDelegate.modelData.name
                    color: wsDelegate.modelData.focused ? Colors.accent : Colors.fg
                    font.family: Colors.fontFamily
                    font.pixelSize: root.fontPixelSize
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wsDelegate.modelData.activate()
            }
        }
    }
}
