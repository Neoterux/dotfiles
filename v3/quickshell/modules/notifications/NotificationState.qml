pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

// Estado compartido de notificaciones -- Quickshell mismo ES el daemon de
// notificaciones (reemplaza a swaync, ver hyprland-neo/autostart/init.lua)
// via NotificationServer, que registra org.freedesktop.Notifications en
// DBus. Solo un proceso puede tener ese nombre a la vez, por eso no
// convive con swaync corriendo -- ver v3/CLAUDE.md.
//
// `pragma Singleton` para que NotificationPopup.qml (los toasts, uno por
// monitor) y NotificationCenter.qml (el icono+historial de la barra) vean
// el mismo estado sin duplicar el server ni pasarlo a mano por cada
// componente intermedio.
QtObject {
    id: root

    property bool doNotDisturb: false
    // Ids de las notificaciones que siguen mostrandose como toast --
    // independiente de `tracked` (que es "sigue en el historial"). Un
    // toast se saca de aca solo (su propio timer) sin afectar el
    // historial; el historial se vacia solo con "olvidar"/dismiss.
    property var popupIds: []

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: notif => {
            notif.tracked = true;
            if (!root.doNotDisturb)
                root.showPopup(notif);
        }
    }

    function findTracked(id) {
        const list = root.server.trackedNotifications.values;
        for (const n of list) {
            if (n.id === id)
                return n;
        }
        return null;
    }

    function showPopup(notif) {
        root.popupIds = [...root.popupIds, notif.id];
        // 0/-1 son "el sender no pidio un timeout especifico" segun la
        // spec de freedesktop -- 5s de default es lo que usan la mayoria
        // de daemons (mako, dunst) para ese caso.
        const ms = notif.expireTimeout > 0 ? notif.expireTimeout : 5000;
        popupTimer.createObject(root, {
            targetId: notif.id,
            interval: ms
        });
    }

    function dismissPopup(id) {
        root.popupIds = root.popupIds.filter(i => i !== id);
    }

    function clearAll() {
        for (const n of root.server.trackedNotifications.values) {
            n.tracked = false;
        }
    }

    // Componente-fabrica para el timer de auto-cierre de cada popup --
    // uno por notificacion, se autodestruye al disparar. `Qt.createComponent`
    // no hace falta: un Component inline + createObject alcanza.
    property Component popupTimer: Component {
        Timer {
            id: t
            property int targetId: -1
            running: true
            repeat: false
            onTriggered: {
                root.dismissPopup(targetId);
                t.destroy();
            }
        }
    }
}
