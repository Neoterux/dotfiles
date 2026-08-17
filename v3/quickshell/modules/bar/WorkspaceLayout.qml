import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland
import "../../theme"
import "../drawer"

// Selector del layout de tiling del workspace ACTIVO de este monitor
// (dwindle / master / scrolling / monocle).
//
// Por que via `hyprctl eval` y no un dispatcher: en Hyprland 0.56 el layout
// es una propiedad POR WORKSPACE (`tiledLayout` en `hyprctl -j workspaces`)
// y lo unico que lo cambia es una workspace rule con campo `layout`. No hay
// dispatcher para eso, y con la config en Lua `hyprctl keyword` esta
// deshabilitado de entrada ("keyword can't work with non-legacy parsers"),
// asi que queda la llamada Lua cruda -- misma idea que PowerMenu llamando a
// `hl.dsp.exit()`. Verificado en vivo: la regla se aplica al instante y
// retroactivamente sobre las ventanas que ya estan en el workspace.
//
// OJO: es una regla de RUNTIME. Un reload de la config de Hyprland la
// borra y el workspace vuelve al layout global (`general.layout`).
//
// Los iconos van como escapes unicode (\uXXXX), no como glifo pegado --
// ver la nota de Volume.qml.
Pill {
    id: root

    required property var panelWindow
    property bool expanded: false
    // Pedido que llego mientras el `hyprctl eval` anterior seguia vivo.
    // Quickshell ignora un cambio de `command` con el Process corriendo,
    // asi que sin esta cola una rueda rapida perderia el ultimo pedido.
    property string queued: ""

    bg: Colors.workspaceActiveBgTranslucent
    fg: Colors.fg
    interactive: true

    // El workspace que importa es el de ESTE monitor, no el que tiene el
    // foco global: si no, la barra del monitor secundario mostraria (y
    // cambiaria) el layout del otro.
    readonly property var monitor: root.panelWindow ? Hyprland.monitorFor(root.panelWindow.screen) : null

    // El workspace especial (scratchpad) NO aparece nunca como
    // `activeWorkspace`: Hyprland lo lleva en un slot aparte por monitor
    // (`specialWorkspace` en `hyprctl -j monitors`) y lo deja superpuesto
    // sobre el workspace normal, que sigue figurando como el activo. Sin
    // esto, con el scratchpad abierto el pill mostraba y cambiaba el layout
    // del workspace de abajo. Quickshell no expone ese slot como propiedad
    // de HyprlandMonitor, asi que sale del IPC crudo; cuando esta vacio el
    // nombre viene como "" (y el id como 0).
    readonly property string specialName: {
        const ipc = root.monitor ? root.monitor.lastIpcObject : null;
        const special = ipc ? ipc.specialWorkspace : null;
        return special && special.name ? String(special.name) : "";
    }
    readonly property var workspace: {
        if (root.specialName)
            return Hyprland.workspaces.values.find(w => w.name === root.specialName) || null;
        return root.monitor ? root.monitor.activeWorkspace : null;
    }
    readonly property string wsName: root.workspace ? root.workspace.name : ""
    readonly property bool onSpecial: root.wsName.indexOf("special:") === 0
    readonly property string wsLabel: root.onSpecial ? "scratchpad " + root.wsName.substring(8) : "workspace " + root.wsName

    // Abrir/cerrar el scratchpad no toca el `activeWorkspace` del monitor,
    // asi que ni `monitorFor(...).activeWorkspace` ni `focusedWorkspace`
    // cambian y ningun binding se entera solo -- el unico aviso es este
    // evento. Re-listar los monitores actualiza `lastIpcObject` (de donde
    // sale `specialName`) y con eso se recalcula todo lo de arriba.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2")
                Hyprland.refreshMonitors();
        }
    }
    readonly property string currentLayout: {
        const ipc = root.workspace ? root.workspace.lastIpcObject : null;
        return ipc && ipc.tiledLayout ? String(ipc.tiledLayout) : "";
    }

    readonly property var layouts: [
        {
            name: "dwindle",
            icon: "\u{f0e8}", // nf-fa-sitemap
            hint: "arbol binario"
        },
        {
            name: "master",
            icon: "\u{f0db}", // nf-fa-columns
            hint: "principal + pila"
        },
        {
            name: "scrolling",
            icon: "\u{f07e}", // nf-fa-arrows_h
            hint: "columnas scrollables"
        },
        {
            name: "monocle",
            icon: "\u{f2d0}", // nf-fa-window_maximize
            hint: "una ventana a la vez"
        }
    ]

    function iconFor(name: string): string {
        for (const l of root.layouts) {
            if (l.name === name)
                return l.icon;
        }
        return "\u{f0c9}"; // nf-fa-bars -- layout de plugin ("lua:<nombre>")
    }

    function applyLayout(name: string) {
        if (!root.wsName || name === root.currentLayout)
            return;
        if (applyProc.running) {
            root.queued = name;
            return;
        }
        root.queued = "";
        // El nombre del workspace entra en un string literal de Lua; los
        // unicos nombres que produce esta config son numeros y
        // "special:<algo>", pero se escapa igual por las dudas.
        const ws = root.wsName.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
        applyProc.command = ["hyprctl", "eval", "hl.workspace_rule({ workspace = \"" + ws + "\", layout = \"" + name + "\" })"];
        applyProc.running = true;
    }

    function cycle(step: int) {
        const names = root.layouts.map(l => l.name);
        const i = Math.max(0, names.indexOf(root.currentLayout));
        root.applyLayout(names[(i + step + names.length) % names.length]);
    }

    // Cambiar de workspace SI emite evento IPC (Quickshell reacciona solo y
    // `activeWorkspace` cambia), pero el `lastIpcObject` del workspace nuevo
    // puede venir de la ultima vez que se listaron -- y el layout pudo haber
    // cambiado desde afuera en el medio (otro monitor, un reload). Re-listar
    // al entrar es una sola ida y vuelta por el socket.
    onWsNameChanged: Hyprland.refreshWorkspaces()

    Process {
        id: applyProc
        onExited: {
            // Una workspace rule nueva no emite NINGUN evento IPC, asi que
            // Quickshell no se entera por su cuenta: hay que re-listar los
            // workspaces para que `lastIpcObject.tiledLayout` refleje lo
            // que se acaba de aplicar.
            Hyprland.refreshWorkspaces();
            const pending = root.queued;
            root.queued = "";
            if (pending)
                root.applyLayout(pending);
        }
    }

    Text {
        // Con el scratchpad abierto el pill pasa a hablar de OTRO workspace
        // que el que se ve en el pill de Workspaces -- sin una marca, el
        // cambio de significado es invisible. Mismo glifo que usa
        // Workspaces.qml para el scratchpad.
        text: (root.onSpecial ? "\u{f0d0} " : "") + root.iconFor(root.currentLayout) + "  " + (root.currentLayout || "?")
        color: root.fg
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize
    }

    onLeftClicked: root.expanded = !root.expanded
    onRightClicked: root.cycle(1)
    onWheelUp: root.cycle(-1)
    onWheelDown: root.cycle(1)

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded

        ColumnLayout {
            // `width` explicito y no `Layout.preferredWidth`: el padre
            // directo en Drawer.qml es un Item plano, no un Layout.
            width: 200 * root.uiScale
            spacing: 8 * root.uiScale

            Text {
                text: root.wsName ? "layout \u{b7} " + root.wsLabel : "sin workspace activo"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.uiScale

                Repeater {
                    model: root.layouts

                    delegate: Item {
                        id: option
                        required property var modelData
                        readonly property bool isCurrent: option.modelData.name === root.currentLayout

                        Layout.fillWidth: true
                        implicitHeight: optionRow.implicitHeight + 10 * root.uiScale

                        Rectangle {
                            anchors.fill: parent
                            radius: 6 * root.uiScale
                            color: option.isCurrent ? Qt.darker(Colors.bg, 0.6) : (optionArea.containsMouse ? Qt.lighter(Colors.bg, 1.6) : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                        }

                        RowLayout {
                            id: optionRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8 * root.uiScale
                            spacing: 8 * root.uiScale

                            Text {
                                text: option.modelData.icon
                                color: option.isCurrent ? Colors.accent : Colors.fg
                                font.family: Colors.fontFamily
                                font.pixelSize: 14 * root.uiScale
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: option.modelData.name
                                    color: option.isCurrent ? Colors.accent : Colors.fg
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12 * root.uiScale
                                    font.bold: option.isCurrent
                                }

                                Text {
                                    text: option.modelData.hint
                                    color: Colors.fg
                                    opacity: 0.5
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10 * root.uiScale
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            id: optionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.applyLayout(option.modelData.name);
                                root.expanded = false;
                            }
                        }
                    }
                }
            }

            Text {
                text: "rueda o click derecho: ciclar"
                color: Colors.fg
                opacity: 0.4
                font.family: Colors.fontFamily
                font.pixelSize: 10 * root.uiScale
            }
        }
    }
}
