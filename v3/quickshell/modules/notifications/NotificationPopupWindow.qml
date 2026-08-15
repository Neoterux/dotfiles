import QtQuick
import QtQuick.Layouts
import Quickshell

// Ventana propia (PanelWindow) para los toasts de notificaciones nuevas,
// apilados arriba a la derecha. Solo se instancia una vez, en el monitor
// principal (ver shell.qml) -- mostrar toasts duplicados en cada monitor
// para algo tan efimero no vale la complejidad de rutearlos por foco/
// cursor.
PanelWindow {
    id: root

    property real uiScale: 1.0
    required property var panelScreen

    screen: panelScreen
    anchors {
        top: true
        right: true
    }
    margins {
        top: Math.round(10 * uiScale)
        right: Math.round(10 * uiScale)
    }

    implicitWidth: 340 * uiScale
    implicitHeight: col.implicitHeight
    color: "transparent"
    exclusiveZone: 0
    // Sin foco de teclado/mouse real -- son toasts informativos, no hay
    // nada que tipear aca. Los botones de accion/cerrar igual reciben
    // clicks normales (eso no depende de esto).
    focusable: false

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8 * root.uiScale

        Repeater {
            model: NotificationState.popupIds

            delegate: NotificationToast {
                id: toastDelegate
                required property var modelData

                Layout.fillWidth: true
                uiScale: root.uiScale
                notification: NotificationState.findTracked(modelData)
                visible: !!notification

                onCloseRequested: NotificationState.dismissPopup(toastDelegate.modelData)
            }
        }
    }
}
