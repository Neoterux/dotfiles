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
//       "engine": "postgres", "latencyMs": 42,
//       "checkedAt": "2026-08-09T21:00:00Z", "note": "",
//       "metrics": [ { "label": "conn", "value": "42/100",
//                      "level": "warn", "ratio": 0.42 } ] }
//   ]
// `status` es uno de "up" | "down" | "degraded" | "unknown" (cualquier
// otro valor cae a "unknown"). Solo "name" es obligatorio -- el resto es
// opcional y se omite en la tarjeta si no viene.
//
// `metrics` es una lista generica de indicadores: la tab NO sabe nada de
// bases de datos ni de motores, solo dibuja label/value y colorea segun
// `level` ("ok" | "warn" | "crit"). Cualquier checker futuro (HTTP, colas,
// lo que sea) puede llenarla sin tocar este archivo. `ratio` (0..1) es
// opcional y agrega la barrita de uso debajo del valor -- solo tiene
// sentido en metricas que son "usado de un maximo".
//
// Ver scripts/check-db-servers.py (checker de BDD, ya hecho) y
// scripts/update-server-status.example.sh (plantilla para uno propio).
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

    // Solo warn/crit se colorean: si "ok" tambien pintara, la tarjeta
    // quedaria toda de colores y no se distinguiria de un vistazo cual es
    // el indicador que hay que mirar.
    function levelColor(level) {
        switch (level) {
        case "crit": return Colors.statusDown;
        case "warn": return Colors.statusDegraded;
        default: return Colors.fg;
        }
    }

    function barColor(level) {
        switch (level) {
        case "crit": return Colors.statusDown;
        case "warn": return Colors.statusDegraded;
        default: return Colors.statusUp;
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
        text: "sin datos -- configura tus servidores en\n~/.config/quickshell/db-servers.json y corre\nscripts/check-db-servers.py"
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
            // OJO: aca NO sirve Array.isArray, aunque en el `reload()` de
            // arriba si. Al array de nivel superior lo devuelve JSON.parse y
            // es un Array de verdad; este viene anidado y pasa por el modelo
            // del Repeater, asi que Qt lo entrega envuelto en un V4Sequence
            // (`Object.prototype.toString` da "[object V4Sequence]"). Sobre
            // eso Array.isArray da false y la grilla entera quedaba invisible
            // -- con los datos ahi, accesibles por indice y con .length bien.
            // Se chequea por length, que el V4Sequence si expone.
            readonly property var metrics: {
                const m = card.modelData.metrics;
                return (m && typeof m === "object" && m.length > 0) ? m : [];
            }

            readonly property color tint: root.statusColor(card.status)

            // 268px sale de la cuenta del renglon del titulo con el nombre
            // real mas largo del usuario ("[PG] Produccion W/R", 19 chars):
            // JetBrains Mono avanza 0.6em, o sea 7.8px por caracter a 13px
            // => 148px de nombre + 9 del punto + 16 de spacings + 48 de la
            // palabra "degraded" + 20 de margenes = 241. Con 232 no entraba
            // y el nombre salia cortado.
            Layout.preferredWidth: 268 * root.uiScale
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
                    Layout.fillWidth: true
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
                        // Ensanchar la tarjeta soluciona los nombres que hay
                        // hoy, no los que el usuario ponga mañana: con dos
                        // lineas un nombre largo se lee entero en vez de
                        // perder el final, que suele ser lo que distingue
                        // una entrada de otra ("... R1" vs "... R2").
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
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

                // Motor y direccion comparten renglon: el motor solo no
                // justifica gastar una linea entera de la tarjeta.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5 * root.uiScale
                    visible: !!card.modelData.url || !!card.modelData.engine

                    Text {
                        visible: !!card.modelData.engine
                        text: card.modelData.engine || ""
                        color: Colors.accent
                        opacity: 0.85
                        font.family: Colors.fontFamily
                        font.pixelSize: 9 * root.uiScale
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.url || ""
                        color: Colors.fg
                        opacity: 0.6
                        font.family: Colors.fontFamily
                        font.pixelSize: 10 * root.uiScale
                        elide: Text.ElideLeft
                    }
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

                Rectangle {
                    visible: card.metrics.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 3 * root.uiScale
                    Layout.preferredHeight: Math.max(1, root.uiScale)
                    color: Colors.fg
                    opacity: 0.12
                }

                GridLayout {
                    visible: card.metrics.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 2 * root.uiScale
                    columns: 2
                    columnSpacing: 10 * root.uiScale
                    rowSpacing: 3 * root.uiScale

                    Repeater {
                        model: card.metrics

                        delegate: ColumnLayout {
                            id: metricCell
                            required property var modelData

                            // fillWidth + preferredWidth igual en las dos
                            // celdas es lo que las reparte 50/50: sin el
                            // preferredWidth, cada columna se dimensiona
                            // segun su texto y la grilla queda despareja.
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 1 * root.uiScale

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4 * root.uiScale

                                Text {
                                    text: metricCell.modelData.label || ""
                                    color: Colors.fg
                                    opacity: 0.45
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 9 * root.uiScale
                                    elide: Text.ElideRight
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: metricCell.modelData.value !== undefined ? String(metricCell.modelData.value) : ""
                                    color: root.levelColor(metricCell.modelData.level)
                                    opacity: metricCell.modelData.level === "warn" || metricCell.modelData.level === "crit" ? 1 : 0.85
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10 * root.uiScale
                                    font.bold: metricCell.modelData.level === "crit"
                                }
                            }

                            Rectangle {
                                visible: typeof metricCell.modelData.ratio === "number"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 2 * root.uiScale
                                radius: height / 2
                                // Alpha en el color, NO `opacity`: la opacity
                                // de un Rectangle la heredan sus hijos, y el
                                // relleno de la barra quedaria invisible.
                                color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.15)

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, metricCell.modelData.ratio || 0))
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.barColor(metricCell.modelData.level)

                                    Behavior on width {
                                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2 * root.uiScale
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
