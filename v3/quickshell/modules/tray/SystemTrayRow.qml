import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

// Fila de iconos de la bandeja del sistema: apps como Discord o Steam
// registran su applet aca via el protocolo StatusNotifierItem (SNI/KDE
// tray), sin que haya que hacer nada especifico por cada app -- cualquier
// cosa que hable ese protocolo aparece sola.
RowLayout {
    id: root

    property real uiScale: 1.0
    required property var panelWindow

    spacing: 2 * uiScale

    Repeater {
        model: SystemTray.items.values

        delegate: TrayItem {
            required property var modelData
            trayItem: modelData
            uiScale: root.uiScale
            panelWindow: root.panelWindow
        }
    }
}
