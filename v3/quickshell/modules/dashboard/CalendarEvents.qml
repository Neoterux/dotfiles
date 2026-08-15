import QtQuick
import Quickshell
import Quickshell.Io

// Fuente de datos del calendario externo (ICS/Nylas), sin UI propia --
// Calendar.qml (los puntitos en la grilla) y TodayEvents.qml (la lista de
// "Hoy") leen de aca en vez de cada uno pegandole a la config/fetch por su
// cuenta. Ver DashboardTab.qml por como se instancia una sola vez y se
// pasa a ambos.
//
// Formato esperado de ~/.local/state/quickshell/calendar.json:
//   {
//     "provider": "ics" | "nylas" | "none",
//     "ics": {
//       "url": "https://.../calendar.ics",
//       "username": "",
//       "password": ""
//     },
//     "nylas": { "apiKey": "", "grantId": "", "region": "us" }
//   }
// `provider` falta o es "none" -> sin eventos, sin warning, sin fetch.
// Mismo patron que ServersTab.qml (JSON externo, no versionado).
//
// `ics.username`/`ics.password` son opcionales -- van como HTTP Basic Auth,
// que es lo que pide DavMail (ver scripts/CALENDAR.md para la guia
// completa de Outlook/Exchange via DavMail, incluida la alternativa mas
// confiable de sincronizar a un .ics LOCAL con vdirsyncer). Si `ics.url`
// no empieza con "http://"/"https://" se trata como ruta de archivo local
// (via FileView, no XHR) -- soporta tanto "file:///ruta" como "/ruta" o
// "~/ruta" pelados, justamente para ese caso.
//
// NOTA sobre Nylas: implementado contra la forma documentada de su API v3
// (GET /v3/grants/{grantId}/events con Bearer token) pero no hay cuenta
// real en esta maquina para probarlo en vivo -- si algo no matchea, es lo
// primero a revisar contra la doc actual de Nylas.
//
// NOTA sobre ICS: el parser cubre VEVENT con DTSTART/DTEND/SUMMARY (fecha
// sola o fecha+hora, UTC con "Z" o "flotante"/local), el caso comun de
// Outlook/Google -- verificado en vivo contra un feed de prueba (fechas,
// horarios con conversion UTC->local, y texto con comas escapadas, todo
// correcto). RRULE (eventos recurrentes) NO se expande -- se ve el primer
// horario tal cual venga, no cada repeticion.
Item {
    id: root

    property string provider: "none"
    property string icsUrl: ""
    property string icsUsername: ""
    property string icsPassword: ""
    property string nylasApiKey: ""
    property string nylasGrantId: ""
    property string nylasRegion: "us"
    property var events: []
    property string statusText: ""

    readonly property date today: new Date()

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    readonly property var todayEvents: root.events.filter(e => e.start && root.isSameDay(e.start, root.today)).sort((a, b) => a.start - b.start)
    readonly property var eventDayKeys: {
        const set = {};
        for (const e of root.events) {
            if (e.start)
                set[e.start.getFullYear() + "-" + e.start.getMonth() + "-" + e.start.getDate()] = true;
        }
        return set;
    }

    function unescapeIcsText(s) {
        return s.replace(/\\n/gi, " ").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
    }

    function parseIcsDate(value) {
        if (/^\d{8}$/.test(value)) {
            return new Date(Number(value.slice(0, 4)), Number(value.slice(4, 6)) - 1, Number(value.slice(6, 8)));
        }
        const m = value.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/);
        if (!m)
            return null;
        const [, y, mo, d, h, mi, s, z] = m;
        if (z === "Z")
            return new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s)));
        return new Date(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s));
    }

    function parseIcs(text) {
        const rawLines = text.split(/\r\n|\n|\r/);
        const lines = [];
        for (const line of rawLines) {
            if ((line.startsWith(" ") || line.startsWith("\t")) && lines.length > 0)
                lines[lines.length - 1] += line.slice(1);
            else
                lines.push(line);
        }

        const evts = [];
        let cur = null;
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") {
                cur = {};
            } else if (line === "END:VEVENT") {
                if (cur && cur.title && cur.start)
                    evts.push(cur);
                cur = null;
            } else if (cur) {
                const idx = line.indexOf(":");
                if (idx < 0)
                    continue;
                const rawKey = line.slice(0, idx);
                const value = line.slice(idx + 1);
                const key = rawKey.split(";")[0].toUpperCase();
                if (key === "SUMMARY")
                    cur.title = root.unescapeIcsText(value);
                else if (key === "DTSTART") {
                    cur.start = root.parseIcsDate(value);
                    cur.allDay = /^\d{8}$/.test(value);
                } else if (key === "DTEND") {
                    cur.end = root.parseIcsDate(value);
                } else if (key === "LOCATION") {
                    cur.location = root.unescapeIcsText(value);
                }
            }
        }
        return evts;
    }

    // true para "/ruta", "~/ruta" o "file://ruta" -- todo lo que no sea un
    // fetch de red. `~` se expande a mano porque FileView no lo hace solo.
    function isLocalIcsPath(url) {
        return !/^https?:\/\//i.test(url);
    }

    function expandLocalPath(url) {
        let p = url.startsWith("file://") ? url.slice("file://".length) : url;
        if (p.startsWith("~/"))
            p = `${Quickshell.env("HOME")}/${p.slice(2)}`;
        return p;
    }

    function fetchIcs() {
        if (root.isLocalIcsPath(root.icsUrl)) {
            root.statusText = "cargando...";
            icsFile.path = root.expandLocalPath(root.icsUrl);
            icsFile.reload();
            return;
        }

        root.statusText = "cargando...";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    root.events = root.parseIcs(xhr.responseText);
                    root.statusText = "";
                } catch (e) {
                    root.statusText = "error parseando el ICS: " + e;
                }
            } else {
                root.statusText = "error " + xhr.status + " obteniendo el ICS";
            }
        };
        // Firma con user/password = HTTP Basic Auth -- es lo que pide
        // DavMail (y la mayoria de servidores CalDAV). Con los dos campos
        // vacios, XHR arma la request sin Authorization como siempre.
        if (root.icsUsername)
            xhr.open("GET", root.icsUrl, true, root.icsUsername, root.icsPassword);
        else
            xhr.open("GET", root.icsUrl);
        xhr.send();
    }

    // Solo se usa para el caso "ics.url es un archivo local" (ver
    // fetchIcs). El path real se pisa ahi mismo antes de cada reload().
    FileView {
        id: icsFile
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.events = root.parseIcs(icsFile.text());
                root.statusText = "";
            } catch (e) {
                root.statusText = "error parseando el ICS local: " + e;
            }
        }
        onTextChanged: {
            try {
                root.events = root.parseIcs(icsFile.text());
                root.statusText = "";
            } catch (e) {
                root.statusText = "error parseando el ICS local: " + e;
            }
        }
        onLoadFailed: root.statusText = "no se pudo leer el ICS local (" + icsFile.path + ")"
    }

    function fetchNylas() {
        root.statusText = "cargando (nylas)...";
        const xhr = new XMLHttpRequest();
        const base = root.nylasRegion === "eu" ? "api.eu.nylas.com" : "api.us.nylas.com";
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    const parsed = JSON.parse(xhr.responseText);
                    const list = parsed.data || [];
                    root.events = list.map(e => ({
                                title: e.title || "(sin titulo)",
                                start: e.when && e.when.start_time ? new Date(e.when.start_time * 1000) : (e.when && e.when.date ? new Date(e.when.date) : null),
                                end: e.when && e.when.end_time ? new Date(e.when.end_time * 1000) : null,
                                allDay: !!(e.when && e.when.date),
                                location: e.location || "",
                            })).filter(e => e.start);
                    root.statusText = "";
                } catch (e) {
                    root.statusText = "error leyendo la respuesta de Nylas: " + e;
                }
            } else {
                root.statusText = "error " + xhr.status + " (nylas)";
            }
        };
        xhr.open("GET", `https://${base}/v3/grants/${root.nylasGrantId}/events?limit=50`);
        xhr.setRequestHeader("Authorization", "Bearer " + root.nylasApiKey);
        xhr.send();
    }

    function refetch() {
        if (root.provider === "ics" && root.icsUrl) {
            root.fetchIcs();
        } else if (root.provider === "nylas" && root.nylasApiKey && root.nylasGrantId) {
            root.fetchNylas();
        } else {
            root.events = [];
            root.statusText = "";
        }
    }

    function applyConfig() {
        let cfg = {};
        try {
            const raw = configFile.text().trim();
            if (raw)
                cfg = JSON.parse(raw);
        } catch (e) {
            cfg = {};
        }
        root.provider = cfg.provider || "none";
        root.icsUrl = (cfg.ics && cfg.ics.url) || "";
        root.icsUsername = (cfg.ics && cfg.ics.username) || "";
        root.icsPassword = (cfg.ics && cfg.ics.password) || "";
        root.nylasApiKey = (cfg.nylas && cfg.nylas.apiKey) || "";
        root.nylasGrantId = (cfg.nylas && cfg.nylas.grantId) || "";
        root.nylasRegion = (cfg.nylas && cfg.nylas.region) || "us";
        root.refetch();
    }

    FileView {
        id: configFile
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/calendar.json`
        watchChanges: true
        printErrors: false
        onLoaded: root.applyConfig()
        onTextChanged: root.applyConfig()
        onLoadFailed: root.applyConfig()
    }

    // ICS/Nylas no avisan solos cuando cambian -- se refresca cada 15min,
    // holgado a proposito (un calendario no cambia segundo a segundo, y
    // no vale la pena pegarle mas seguido a una API externa por esto).
    Timer {
        interval: 15 * 60 * 1000
        running: root.provider !== "none"
        repeat: true
        onTriggered: root.refetch()
    }
}
