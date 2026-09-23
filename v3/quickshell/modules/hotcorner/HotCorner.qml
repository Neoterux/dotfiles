import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Esquina caliente: llevar el cursor a la esquina inferior izquierda del
// monitor muestra/oculta el scratchpad (special:magic), igual que SUPER +
// boton lateral o el pill de Workspaces. Abajo y no arriba porque arriba a
// la izquierda esta el Launcher de la barra.
//
// Una superficie layer-shell diminuta en la capa Overlay (queda encima de
// ventanas en pantalla completa). El cursor se frena en el borde de la
// pantalla, asi que no hace falta mas que unos px para atraparlo.
// `ExclusionMode.Ignore` la clava en la esquina real sin reservar espacio.
//
// El `dwell` evita el disparo accidental al pasar rozando: hay que quedarse
// un instante. Dispara una vez por entrada; para volver a disparar hay que
// salir y entrar de nuevo.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property int dwellMs: 150
    property int size: 4

    anchors {
        bottom: true
        left: true
    }
    implicitWidth: root.size
    implicitHeight: root.size
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Namespace propio: la layer_rule de blur de hyprland-neo matchea
    // `^quickshell$` y a esto no le hace falta vidrio.
    WlrLayershell.namespace: "quickshell-hotcorner"
    // Casi transparente en vez de "transparent" a secas: una superficie con
    // alpha 0 puede quedar sin region de input segun el compositor.
    color: "#01000000"

    Process {
        id: toggleProc
        // Con la config en Lua, `hyprctl dispatch` evalua Lua (ver
        // bar/PowerMenu.qml).
        command: ["hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("magic")']
    }

    Timer {
        id: dwell
        interval: root.dwellMs
        onTriggered: if (!toggleProc.running)
            toggleProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: dwell.restart()
        onExited: dwell.stop()
    }
}
