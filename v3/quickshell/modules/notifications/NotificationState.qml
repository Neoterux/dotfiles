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
    // Tope de toasts simultaneos en pantalla. Sin esto una rafaga (un
    // build largo, un chat activo) apila tarjetas hasta pasarse del borde
    // inferior de la pantalla. Los que se caen del tope siguen enteros en
    // el historial del drawer, solo no muestran toast.
    readonly property int maxPopups: 4

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
        root.popupIds = [...root.popupIds, notif.id].slice(-root.maxPopups);
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

    // OJO: `trackedNotifications.values` es una vista VIVA del modelo, no
    // una copia -- destrackear/descartar un elemento lo saca de la lista
    // en el acto, asi que iterarla mientras se la modifica se saltea uno
    // de cada dos (el sintoma era "limpiar todo limpia la mitad"). El
    // `.slice()` congela la lista antes de tocar nada.
    //
    // `dismiss()` (y no `tracked = false`) para que el que la mando se
    // entere del cierre, igual que el boton X de cada tarjeta. Destruye la
    // notificacion, asi que no hay que tocarle nada mas despues.
    function clearAll() {
        const list = root.server.trackedNotifications.values.slice();
        for (const n of list) {
            // El chequeo no sobra: si alguna ya se destruyo mientras se
            // recorria la copia, su wrapper queda nulo y el TypeError
            // cortaria el for a la mitad, dejando el resto sin limpiar.
            if (n)
                n.dismiss();
        }
        // Los toasts en pantalla apuntan a estas mismas notificaciones: si
        // no se limpian, quedan tarjetas colgadas de un objeto ya
        // destruido (findTracked devuelve null y los bindings tiran error).
        root.popupIds = [];
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
