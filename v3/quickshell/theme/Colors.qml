pragma Singleton
import QtQuick

// Paleta gruvbox, tomada de hyprland-neo/lookandfeel e
// hyprland-legacy/../waybar/style.css para que la barra combine con el resto
// del rice. Al ser `pragma Singleton` dentro de un directorio importado
// (`import "../theme"`), QML lo trata como instancia unica: se referencia
// como `Colors.bg`, `Colors.accent`, etc. sin necesidad de instanciarlo.
QtObject {
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property color bg: "#161320"
    readonly property color bgTranslucent: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.65)
    readonly property color fg: "#ebdbb2"
    readonly property color textDark: "#161320"
    readonly property color accent: "#fe8019"

    readonly property color workspaceBorder: "#fbf1c7"
    readonly property color workspaceActiveBg: "#fbf1c7"
    readonly property color workspaceActiveFg: "#fe8019"
    // Mismo tono que workspaceActiveBg pero translucido, para teñir TODO
    // el contenedor de workspaces (no cada pill individual) con "algo del
    // color del workspace activo" sin volverse un bloque solido opaco.
    readonly property color workspaceActiveBgTranslucent: Qt.rgba(workspaceActiveBg.r, workspaceActiveBg.g, workspaceActiveBg.b, 0.28)

    readonly property color launcher: "#161320"
    readonly property color launcherFg: "#fe8019"
    readonly property color network: "#fb4934"
    readonly property color networkOffline: "#3c3836"
    readonly property color volume: "#fae3b0"
    readonly property color backlight: "#f8bd96"
    readonly property color clock: "#8ec07c"
    readonly property color memory: "#fabd2f"
    readonly property color cpu: "#b8bb26"

    // Estados de servidor para la tab "Servers" del dashboard (ver
    // dashboard/ServersTab.qml). Mismos tonos gruvbox que el resto.
    readonly property color statusUp: "#b8bb26"
    readonly property color statusDegraded: "#fabd2f"
    readonly property color statusDown: "#fb4934"
    readonly property color statusUnknown: "#7c6f64"
}
