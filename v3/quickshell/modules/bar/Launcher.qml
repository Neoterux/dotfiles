import QtQuick
import Quickshell.Io
import "../../theme"
import "../launcher"

// Lanzador de aplicaciones nativo (popup con buscador + grilla de apps,
// ver AppLauncher.qml) en vez de solo invocar rofi a ciegas. Click
// izquierdo abre/cierra el popup; click derecho sigue abriendo rofi por
// si preferis ese flujo.
//
// El icono se escribe como escape unicode (\uXXXX) en vez de pegar el
// glifo directo: pegar el caracter del Nerd Font a mano termino guardando
// un string vacio mas de una vez durante la edicion de este archivo.
Pill {
    id: root
    bg: Colors.launcher
    fg: Colors.launcherFg
    interactive: true

    required property var panelWindow
    property bool expanded: false

    Text {
        // nf-fa-rocket, mismo codepoint que usa "custom/launcher" en waybar/config
        text: "\u{f08c7}"
        color: root.fg
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize + 2
    }

    Process {
        id: rofiProc
        command: ["rofi", "-show", "drun"]
    }

    onLeftClicked: root.expanded = !root.expanded
    onRightClicked: rofiProc.startDetached()

    LauncherPanel {
        panelScreen: root.panelWindow.screen
        uiScale: root.uiScale
        shown: root.expanded
        onDismissed: root.expanded = false
    }
}
