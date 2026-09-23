import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../theme"

// Indicador de paginas del layout "stacked-dwindle" (hypr/hyprland-neo/
// stacked-dwindle). Un punto por pagina del workspace activo de ESTE
// monitor, el visible resaltado; click en un punto salta a esa pagina, la
// rueda recorre las paginas (hacia abajo desde la ultima abre una nueva,
// igual que SUPER + SHIFT + rueda) y el "+" abre una pagina vacia.
//
// Solo se muestra si ese workspace usa el layout.
//
// De donde sale el estado: el layout vive en Lua dentro de Hyprland y no
// tiene IPC propio, asi que publica {"<ws>":{"active":n,"count":m}} en
// $XDG_RUNTIME_DIR/hyprland-neo/stacked-dwindle.json cada vez que cambia.
// Es un archivo comun en tmpfs, asi que `watchChanges` (inotify) si
// dispara -- a diferencia de /proc -- pero `text()` igual no se relee solo:
// hay que llamar a `reload()` (ver la nota de FileView en CLAUDE.md).
Pill {
    id: root

    required property var panelWindow

    bg: Colors.workspaceActiveBgTranslucent
    fg: Colors.fg
    hPadding: 7 * uiScale
    visible: root.isStacked && root.count > 0

    readonly property var monitor: root.panelWindow ? Hyprland.monitorFor(root.panelWindow.screen) : null
    readonly property var workspace: root.monitor ? root.monitor.activeWorkspace : null
    readonly property bool isStacked: {
        const ipc = root.workspace ? root.workspace.lastIpcObject : null;
        return !!ipc && ipc.tiledLayout === "lua:stacked-dwindle";
    }

    property var pages: ({})
    readonly property var entry: root.workspace ? root.pages[String(root.workspace.id)] : undefined
    readonly property int count: root.entry ? root.entry.count : 0
    readonly property int active: root.entry ? root.entry.active : 0

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
                root.pages = JSON.parse(stateFile.text());
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

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.send(event.angleDelta.y < 0 ? "page down" : "page up")
    }

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
                opacity: dot.isActive ? 1 : (dotArea.containsMouse ? 0.8 : 0.4)

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: dotArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.send("page " + (dot.index + 1))
            }
        }
    }

    Item {
        implicitWidth: 12 * root.uiScale
        implicitHeight: 16 * root.uiScale

        Text {
            anchors.centerIn: parent
            text: "+"
            color: Colors.fg
            opacity: plusArea.containsMouse ? 0.9 : 0.45
            font.family: Colors.fontFamily
            font.pixelSize: root.fontPixelSize
            font.bold: true
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
