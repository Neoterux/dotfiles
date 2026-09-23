import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import "../../theme"
import "../drawer"

// Indicador de paginas del layout "stacked-dwindle" (hypr/hyprland-neo/
// stacked-dwindle). En la barra, un punto por pagina del workspace activo
// de ESTE monitor, el visible resaltado; la rueda recorre las paginas (hacia
// abajo desde la ultima abre una nueva, igual que SUPER + SHIFT + rueda).
//
// Al pasar el mouse (o click) se abre un drawer con una tarjeta por pagina
// y los iconos de sus apps: click salta a esa pagina, ARRASTRAR una tarjeta
// la reordena (`movepage <de> <a>`), y la tarjeta "+" abre una pagina vacia.
//
// Solo se muestra si ese workspace usa el layout.
//
// De donde sale el estado: el layout vive en Lua dentro de Hyprland y no
// tiene IPC propio, asi que publica
// {"<ws>":{"active":n,"count":m,"pages":[["kitty",...],...]}} en
// $XDG_RUNTIME_DIR/hyprland-neo/stacked-dwindle.json cada vez que cambia.
// Es un archivo comun en tmpfs, asi que `watchChanges` (inotify) si
// dispara -- a diferencia de /proc -- pero `text()` igual no se relee solo:
// hay que llamar a `reload()` (ver la nota de FileView en CLAUDE.md).
Pill {
    id: root

    required property var panelWindow
    property bool expanded: false
    // Alguna tarjeta del drawer esta agarrada: mientras tanto el drawer no
    // se cierra aunque el mouse se salga (ver `hoverHold` en Drawer.qml).
    property bool dragging: false

    bg: Colors.workspaceActiveBgTranslucent
    fg: Colors.fg
    hPadding: 7 * uiScale
    interactive: true
    visible: root.isStacked && root.count > 0

    readonly property var monitor: root.panelWindow ? Hyprland.monitorFor(root.panelWindow.screen) : null
    readonly property var workspace: root.monitor ? root.monitor.activeWorkspace : null
    readonly property bool isStacked: {
        const ipc = root.workspace ? root.workspace.lastIpcObject : null;
        return !!ipc && ipc.tiledLayout === "lua:stacked-dwindle";
    }

    property var pageState: ({})
    readonly property var entry: root.workspace ? root.pageState[String(root.workspace.id)] : undefined
    readonly property int count: root.entry ? root.entry.count : 0
    readonly property int active: root.entry ? root.entry.active : 0
    readonly property var pages: root.entry && root.entry.pages ? root.entry.pages : []

    onVisibleChanged: if (!root.visible)
        root.expanded = false

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprland-neo/stacked-dwindle.json"
        watchChanges: true
        onFileChanged: stateFile.reload()
        onLoaded: {
            // El layout escribe truncando y despues escribiendo: inotify puede
            // avisar entre las dos cosas y llegar un archivo vacio o a medias.
            // Se ignora y se espera al aviso siguiente.
            try {
                root.pageState = JSON.parse(stateFile.text());
            } catch (e) {}
        }
    }

    Process {
        id: pageProc
    }

    // Enfoca el workspace de este monitor antes de mandar el mensaje: el
    // layoutmsg siempre va al workspace ACTIVO, y el click puede venir de la
    // barra del otro monitor.
    function send(msg: string) {
        if (!root.workspace || pageProc.running)
            return;
        pageProc.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + root.workspace.id + " })); hl.dispatch(hl.dsp.layout(\"" + msg + "\"))"];
        pageProc.running = true;
    }

    // Mismo resolvedor que Workspaces.qml: la clase (app_id) no siempre es
    // el nombre del icono, y un nombre inexistente no falla sino que carga
    // el cuadriculado de "imagen rota" -- se valida con hasThemeIcon antes.
    function iconFor(cls: string): string {
        if (!cls)
            return "";
        const entry = DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls);
        const name = entry ? entry.icon : cls;
        return name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }

    onLeftClicked: root.expanded = !root.expanded
    onWheelUp: root.send("page up")
    onWheelDown: root.send("page down")

    Repeater {
        model: root.count

        delegate: Item {
            id: dot
            required property int index
            readonly property bool isActive: dot.index + 1 === root.active

            implicitWidth: 12 * root.uiScale
            implicitHeight: 16 * root.uiScale

            Rectangle {
                anchors.centerIn: parent
                width: dot.isActive ? 10 * root.uiScale : 6 * root.uiScale
                height: width
                radius: width / 2
                color: dot.isActive ? Colors.accent : Colors.fg
                opacity: dot.isActive ? 1 : 0.4

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Drawer {
        anchorItem: root
        panelWindow: root.panelWindow
        uiScale: root.uiScale
        shown: root.expanded
        hoverOpen: true
        hoverSource: root
        hoverHold: root.dragging
        onOpenRequested: root.expanded = true
        onCloseRequested: root.expanded = false
        onEscapePressed: root.expanded = false

        ColumnLayout {
            spacing: 8 * root.uiScale

            Text {
                text: "paginas \u{b7} workspace " + (root.workspace ? root.workspace.name : "")
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.bold: true
            }

            // Fila de tarjetas. Cada `slot` queda fijo en su lugar y lo que se
            // arrastra es la tarjeta de adentro; al soltar, la posicion se
            // traduce a un indice de slot. Asi el Row nunca se reacomoda a
            // mitad del arrastre (el reorden real lo hace el layout, y el
            // archivo de estado trae el orden nuevo).
            Item {
                id: strip

                readonly property real cardW: 76 * root.uiScale
                readonly property real cardH: 52 * root.uiScale
                readonly property real gap: 8 * root.uiScale
                readonly property real stride: strip.cardW + strip.gap
                // Slot sobre el que caeria la tarjeta arrastrada (-1: ninguno).
                property int dropIndex: -1

                implicitWidth: (root.count + 1) * strip.stride - strip.gap
                implicitHeight: strip.cardH

                function slotAt(x: real): int {
                    return Math.max(0, Math.min(root.count - 1, Math.round(x / strip.stride)));
                }

                Repeater {
                    model: root.count

                    delegate: Item {
                        id: slot
                        required property int index
                        readonly property var apps: root.pages[slot.index] || []
                        readonly property bool isActive: slot.index + 1 === root.active
                        readonly property bool isDropTarget: strip.dropIndex === slot.index && dragArea.drag.active === false && root.dragging

                        x: slot.index * strip.stride
                        width: strip.cardW
                        height: strip.cardH
                        z: dragArea.drag.active ? 10 : 0

                        // Marca de donde va a caer la tarjeta arrastrada.
                        Rectangle {
                            anchors.fill: parent
                            radius: 8 * root.uiScale
                            color: "transparent"
                            border.width: 1.5
                            border.color: Colors.accent
                            opacity: slot.isDropTarget ? 0.9 : 0
                        }

                        Rectangle {
                            id: card
                            width: strip.cardW
                            height: strip.cardH
                            radius: 8 * root.uiScale
                            color: slot.isActive ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22) : (dragArea.containsMouse ? Qt.lighter(Colors.bg, 1.6) : Qt.rgba(1, 1, 1, 0.04))
                            border.width: slot.isActive ? 1.5 : 1
                            border.color: slot.isActive ? Colors.accent : Qt.rgba(1, 1, 1, 0.12)
                            opacity: dragArea.drag.active ? 0.85 : 1
                            scale: dragArea.drag.active ? 1.05 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 100 }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 5 * root.uiScale
                                text: slot.index + 1
                                color: slot.isActive ? Colors.accent : Colors.fg
                                opacity: slot.isActive ? 1 : 0.6
                                font.family: Colors.fontFamily
                                font.pixelSize: 10 * root.uiScale
                                font.bold: true
                            }

                            // Hasta 4 iconos; si hay mas, "+N".
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 7 * root.uiScale
                                spacing: 3 * root.uiScale

                                Repeater {
                                    model: slot.apps.slice(0, 4)

                                    delegate: Item {
                                        id: app
                                        required property string modelData
                                        readonly property string src: root.iconFor(app.modelData)

                                        width: 16 * root.uiScale
                                        height: 16 * root.uiScale

                                        IconImage {
                                            anchors.fill: parent
                                            visible: app.src !== ""
                                            source: app.src
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: app.src === ""
                                            text: app.modelData ? app.modelData.charAt(0).toUpperCase() : "?"
                                            color: Colors.fg
                                            font.family: Colors.fontFamily
                                            font.pixelSize: 11 * root.uiScale
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    visible: slot.apps.length > 4
                                    text: "+" + (slot.apps.length - 4)
                                    color: Colors.fg
                                    opacity: 0.6
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10 * root.uiScale
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: slot.apps.length === 0
                                    text: "vacia"
                                    color: Colors.fg
                                    opacity: 0.4
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10 * root.uiScale
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                drag.target: card
                                drag.axis: Drag.XAxis
                                drag.minimumX: -slot.x
                                drag.maximumX: (root.count - 1) * strip.stride - slot.x
                                drag.threshold: 6 * root.uiScale

                                onPressed: root.dragging = true
                                onPositionChanged: if (drag.active)
                                    strip.dropIndex = strip.slotAt(slot.x + card.x)
                                onReleased: {
                                    const wasDrag = drag.active;
                                    const to = strip.slotAt(slot.x + card.x);
                                    card.x = 0;
                                    strip.dropIndex = -1;
                                    root.dragging = false;
                                    if (!wasDrag)
                                        root.send("page " + (slot.index + 1));
                                    else if (to !== slot.index)
                                        root.send("movepage " + (slot.index + 1) + " " + (to + 1));
                                }
                                onCanceled: {
                                    card.x = 0;
                                    strip.dropIndex = -1;
                                    root.dragging = false;
                                }
                            }
                        }
                    }
                }

                // Tarjeta "+": pagina nueva vacia al final.
                Rectangle {
                    x: root.count * strip.stride
                    width: strip.cardW
                    height: strip.cardH
                    radius: 8 * root.uiScale
                    color: plusArea.containsMouse ? Qt.lighter(Colors.bg, 1.6) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: Colors.fg
                        opacity: plusArea.containsMouse ? 0.9 : 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 18 * root.uiScale
                    }

                    MouseArea {
                        id: plusArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.send("page new")
                    }
                }
            }

            Text {
                text: "arrastra para reordenar \u{b7} click para ir"
                color: Colors.fg
                opacity: 0.4
                font.family: Colors.fontFamily
                font.pixelSize: 10 * root.uiScale
            }
        }
    }
}
