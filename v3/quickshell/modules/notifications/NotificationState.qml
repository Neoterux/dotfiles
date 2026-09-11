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
    // Ids que estan REPRODUCIENDO su animacion de salida. Siguen en
    // `popupIds` (o sea, siguen instanciados y en pantalla) hasta que la
    // animacion termina y el propio toast avisa con finishPopup().
    //
    // Hace falta esta lista intermedia porque el Repeater destruye el
    // delegate en el instante en que el id sale del modelo: sacarlo y
    // "despues" animar es imposible, ya no hay nada que animar. Por eso
    // el timer de expiracion no borra, marca.
    property var exitingIds: []
    // Tope de toasts simultaneos en pantalla. Sin esto una rafaga (un
    // build largo, un chat activo) apila tarjetas hasta pasarse del borde
    // inferior de la pantalla. Los que se caen del tope siguen enteros en
    // el historial del drawer, solo no muestran toast.
    readonly property int maxPopups: 4

    // Tope del HISTORIAL. El server no descarta nada solo: una app que
    // manda notificaciones en rafaga (un build, un chat, un script) deja
    // el historial creciendo sin techo para toda la sesion, y como cada
    // entrada es una tarjeta instanciada de verdad (no una fila liviana),
    // eso es memoria que no vuelve nunca. Los mas viejos se van con
    // expire() -- no dismiss(): al que la mando hay que decirle que
    // caduco, no que el usuario la cerro.
    readonly property int maxHistory: 50

    // Corta el modelo del historial mientras se lo esta vaciando en masa.
    //
    // Es la property mas importante de este archivo. `values` es una vista
    // VIVA: cada dismiss() la cambia, y un modelo de Repeater atado a un
    // array de JS NO hace diff -- se RESETEA entero, destruyendo y
    // recreando todos los delegates que quedan. O sea que borrar N de a
    // uno construia N(N+1)/2 tarjetas. Medido con un Repeater pelado:
    // N=60 -> 1830 delegates creados (60*61/2 exacto). Con tarjetas
    // reales (IconImage, StyledText, capas, animaciones) eso es lo que
    // colgaba el shell y lo dejaba en 18 GB de RSS al tocar "limpiar
    // todo" con el historial lleno.
    //
    // El truco de por que alcanza con un bool: QML captura las
    // dependencias de un binding EN CADA evaluacion, y `a ? b : c` solo
    // evalua una rama. Con `suspended` en true la expresion nunca lee
    // `values`, asi que `values` deja de ser dependencia y los N cambios
    // del bucle no re-disparan nada. Se evalua una sola vez, da vacio, y
    // ahi se queda hasta que se apaga la traba.
    property bool suspended: false

    // Todo lo que muestre el historial tiene que pasar por aca (y no por
    // `server.trackedNotifications.values` directo) o se saltea la traba.
    readonly property var history: root.suspended ? [] : root.server.trackedNotifications.values
    readonly property int count: root.suspended ? 0 : root.server.trackedNotifications.values.length

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
            // El alta en `trackedNotifications` NO es sincronica con este
            // `tracked = true`: recien aparece cuando el handler vuelve.
            // Asi que aca la lista todavia no incluye a `notif` y la poda
            // deja `maxHistory` viejas + la nueva. Medido en vivo con 300
            // notify-send seguidos: se estabiliza en 51, no en 50. El
            // tope es "maxHistory + 1", y esta bien que asi sea -- lo que
            // importa es que haya techo, no cual es el numero exacto.
            root.trimHistory();
            if (!root.doNotDisturb)
                root.showPopup(notif);
        }
    }

    // Poda las mas viejas cuando el historial pasa el tope. Va con la
    // misma traba que clearAll(): son varios expire() seguidos y sin
    // suspender, cada uno resetearia el Repeater del historial entero.
    function trimHistory() {
        const list = root.server.trackedNotifications.values;
        const excess = list.length - root.maxHistory;
        if (excess <= 0)
            return;
        // `values` llega en orden de llegada, asi que los primeros son los
        // mas viejos. Las que estan mostrandose como toast quedan afuera
        // de la poda: si se destruyeran, su tarjeta en pantalla se
        // quedaria apuntando a un objeto muerto. No es un caso real
        // (maxPopups es 4 y los toasts son siempre los mas NUEVOS, nunca
        // los primeros de la lista), pero el guard es una linea.
        const doomed = list.slice(0, excess).filter(n => n && root.popupIds.indexOf(n.id) === -1);
        if (doomed.length === 0)
            return;
        root.suspended = true;
        for (const n of doomed) {
            if (n)
                n.expire();
        }
        root.suspended = false;
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
        // Si el tope se llevo puesto alguno que estaba saliendo, su
        // delegate ya no existe y nunca va a llamar a finishPopup(): sin
        // esta poda su id se quedaria para siempre en la lista.
        root.exitingIds = root.exitingIds.filter(i => root.popupIds.indexOf(i) !== -1);
        // 0/-1 son "el sender no pidio un timeout especifico" segun la
        // spec de freedesktop -- 5s de default es lo que usan la mayoria
        // de daemons (mako, dunst) para ese caso.
        const ms = notif.expireTimeout > 0 ? notif.expireTimeout : 5000;
        popupTimer.createObject(root, {
            targetId: notif.id,
            interval: ms
        });
    }

    // Arranca la salida del toast: NO lo saca de pantalla, lo marca para
    // que se disuelva. Lo llama tanto el timer de expiracion como la X /
    // el click del medio de la tarjeta.
    function dismissPopup(id) {
        if (root.popupIds.indexOf(id) === -1)
            return;
        if (root.exitingIds.indexOf(id) !== -1)
            return;
        root.exitingIds = [...root.exitingIds, id];
    }

    // La llama el toast cuando termino de disolverse. Recien aca
    // desaparece de verdad.
    function finishPopup(id) {
        root.popupIds = root.popupIds.filter(i => i !== id);
        root.exitingIds = root.exitingIds.filter(i => i !== id);
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
        // Los toasts en pantalla apuntan a estas mismas notificaciones,
        // asi que se limpian ANTES del bucle, no despues: mientras el
        // bucle corre, sus bindings se reevaluan con cada dismiss() y
        // findTracked() ya devuelve null para la que se acaba de
        // destruir. Limpiando despues, cada iteracion dejaba una tanda de
        // TypeErrors en el log -- N de ellas, justo cuando lo ultimo que
        // hace falta es escribir al log en un bucle caliente.
        root.popupIds = [];
        root.exitingIds = [];
        // Traba puesta: el modelo del historial se vacia de una y los N
        // dismiss() de abajo no lo vuelven a construir ni una sola vez
        // (ver el comentario de `suspended`). Sin esto, esta misma
        // funcion instanciaba N(N+1)/2 tarjetas.
        root.suspended = true;
        for (const n of list) {
            // El chequeo no sobra: si alguna ya se destruyo mientras se
            // recorria la copia, su wrapper queda nulo y el TypeError
            // cortaria el for a la mitad, dejando el resto sin limpiar.
            if (n)
                n.dismiss();
        }
        root.suspended = false;
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
