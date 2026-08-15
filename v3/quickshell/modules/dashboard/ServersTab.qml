import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"

// Pestaña "Servers": mini dashboard de estado de servidores/infra externa
// a esta maquina (trabajo, homelab, lo que sea). Quickshell no corre nada
// en la red por si solo -- lee un JSON que OTRA cosa (un script tuyo, un
// cron, un systemd timer, corriendo aca o en otra maquina que te lo
// sincronice) escribe en:
//
//   ~/.local/state/quickshell/servers.json
//
// Formato esperado -- un array de objetos:
//   [
//     { "name": "prod-api", "status": "up", "url": "https://...",
//       "latencyMs": 42, "checkedAt": "2026-08-09T21:00:00Z", "note": "" }
//   ]
// `status` es uno de "up" | "down" | "degraded" | "unknown" (cualquier
// otro valor cae a "unknown"). Solo "name" es obligatorio -- el resto es
// opcional y se omite en la tarjeta si no viene.
//
// Ver scripts/update-server-status.example.sh para un punto de partida
// de como escribir ese archivo desde chequeos reales (curl a cada URL).
// `watchChanges: true` hace que esto se actualice solo apenas el archivo
// cambia (inotify), sin poll -- consistente con el resto del dashboard.
GridLayout {
    id: root
    columns: 2
    columnSpacing: 14 * uiScale
    rowSpacing: 10 * uiScale

    property real uiScale: 1.0
    property var servers: []

    function statusColor(status) {
        switch (status) {
        case "up": return Colors.statusUp;
        case "down": return Colors.statusDown;
        case "degraded": return Colors.statusDegraded;
        default: return Colors.statusUnknown;
        }
    }

    function relativeTime(iso) {
        if (!iso)
            return "";
        const then = new Date(iso);
        if (isNaN(then.getTime()))
            return "";
        const secs = Math.max(0, Math.floor((Date.now() - then.getTime()) / 1000));
        if (secs < 60)
            return "hace " + secs + "s";
        if (secs < 3600)
            return "hace " + Math.floor(secs / 60) + "m";
        return "hace " + Math.floor(secs / 3600) + "h";
    }

    // Parsear FileView.text() dentro de un binding declarativo no
    // reacciona cuando termina la carga async (mismo gotcha que
    // hostname/uptime en otros modulos) -- se escucha onLoaded/
    // onTextChanged explicitamente y se parsea ahi.
    function reload() {
        const raw = statusFile.text().trim();
        if (!raw) {
            root.servers = [];
            return;
        }
        try {
            const parsed = JSON.parse(raw);
            root.servers = Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            root.servers = [];
        }
    }

    FileView {
        id: statusFile
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/servers.json`
        watchChanges: true
        // El archivo puede no existir todavia (primer uso) -- eso no es
        // un error real, no hace falta que Quickshell lo grite en el log.
        printErrors: false
        onLoaded: root.reload()
        onTextChanged: root.reload()
        onLoadFailed: root.servers = []
    }

    Text {
        Layout.columnSpan: 2
        visible: root.servers.length === 0
        text: "sin datos -- escribi el estado de tus servidores en\n~/.local/state/quickshell/servers.json"
        color: Colors.fg
        opacity: 0.5
        font.family: Colors.fontFamily
        font.pixelSize: 12 * root.uiScale
        font.italic: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
    }

    Repeater {
        model: root.servers

        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property string status: ["up", "down", "degraded"].includes(card.modelData.status) ? card.modelData.status : "unknown"

            readonly property color tint: root.statusColor(card.status)

            Layout.preferredWidth: 210 * root.uiScale
            Layout.fillHeight: true
            Layout.minimumHeight: content.implicitHeight + 18 * root.uiScale
            radius: 12 * root.uiScale
            // Tinte del color de estado -- mismo criterio visual que
            // MetricCard (Performance) y los workspaces enfocados, en vez
            // del gris plano que tenia antes (el punto de color solo ya
            // no alcanzaba para leer el estado de un vistazo).
            color: Qt.rgba(card.tint.r, card.tint.g, card.tint.b, 0.1)
            border.width: 1
            border.color: Qt.rgba(card.tint.r, card.tint.g, card.tint.b, 0.3)

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 10 * root.uiScale
                spacing: 4 * root.uiScale

                RowLayout {
                    spacing: 8 * root.uiScale

                    Rectangle {
                        Layout.preferredWidth: 9 * root.uiScale
                        Layout.preferredHeight: 9 * root.uiScale
                        radius: width / 2
                        color: root.statusColor(card.status)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.name || "?"
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 13 * root.uiScale
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: card.status
                        color: root.statusColor(card.status)
                        font.family: Colors.fontFamily
                        font.pixelSize: 10 * root.uiScale
                        font.bold: true
                    }
                }

                Text {
                    visible: !!card.modelData.url
                    Layout.fillWidth: true
                    text: card.modelData.url || ""
                    color: Colors.fg
                    opacity: 0.6
                    font.family: Colors.fontFamily
                    font.pixelSize: 10 * root.uiScale
                    elide: Text.ElideRight
                }

                Text {
                    visible: !!card.modelData.note
                    Layout.fillWidth: true
                    text: card.modelData.note || ""
                    color: Colors.fg
                    opacity: 0.75
                    font.family: Colors.fontFamily
                    font.pixelSize: 10 * root.uiScale
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6 * root.uiScale

                    Text {
                        visible: card.modelData.latencyMs !== undefined
                        text: card.modelData.latencyMs + "ms"
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 9 * root.uiScale
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: !!card.modelData.checkedAt
                        text: root.relativeTime(card.modelData.checkedAt)
                        color: Colors.fg
                        opacity: 0.5
                        font.family: Colors.fontFamily
                        font.pixelSize: 9 * root.uiScale
                    }
                }
            }
        }
    }
}
