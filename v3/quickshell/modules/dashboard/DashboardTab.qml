import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme"

// Pestaña "Dashboard": mosaico de tarjetas (saludo+hora, sistema,
// calendario, eventos de hoy) en vez de una sola columna vertical larga
// -- la version anterior apilaba TODO (hora, fecha, nav de mes, grilla,
// lista de eventos, link "hoy") en una unica ColumnLayout angosta y se
// sentia demasiado vertical/apretada. Ahora son 4 tarjetas en 2 filas de
// 2, mismo lenguaje visual tenido que Performance/Media/Workspaces.
ColumnLayout {
    id: root
    spacing: 14 * uiScale

    property real uiScale: 1.0
    property string distro: ""
    property string uptimeText: ""
    readonly property string userName: Quickshell.env("USER") || ""

    readonly property int cardWidth: 260

    // Font.Capitalize (font.capitalization) pone en mayuscula CADA
    // palabra ("Domingo 9 De Agosto"), que no es como se escribe en
    // castellano -- esto solo mayuscula la primera letra. (Duplicada de
    // Calendar.qml a proposito: son 2 lineas, no vale la pena una
    // dependencia cruzada solo por esto.)
    function cap1(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    function greeting() {
        const h = new Date().getHours();
        if (h < 6)
            return "Buena madrugada";
        if (h < 12)
            return "Buenos días";
        if (h < 20)
            return "Buenas tardes";
        return "Buenas noches";
    }

    // Llamar FileView.text() dentro de un binding declarativo NO
    // reacciona cuando termina la carga async (probado con el hostname
    // del reloj, se quedaba pegado en vacio). La forma confiable es
    // escuchar `onLoaded`/`onTextChanged` explicitamente.
    function sampleUptime() {
        const secs = Math.floor(Number(uptimeFile.text().split(" ")[0]) || 0);
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        root.uptimeText = h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    Process {
        id: distroProc
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\""]
        stdout: StdioCollector {
            onStreamFinished: root.distro = text.trim()
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.sampleUptime()
        onTextChanged: root.sampleUptime()
    }

    Component.onCompleted: distroProc.running = true

    // /proc/uptime no dispara file-watch (procfs no soporta inotify para
    // esto), asi que ademas se fuerza una relectura cada minuto.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            uptimeFile.reload();
            root.sampleUptime();
        }
    }

    // Fuente de datos de eventos externos, una sola vez -- Calendar (los
    // puntitos) y TodayEvents (la lista) leen de aca, ver
    // CalendarEvents.qml.
    CalendarEvents {
        id: calEvents
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14 * root.uiScale

        DashboardCard {
            uiScale: root.uiScale
            tint: Colors.accent
            Layout.preferredWidth: root.cardWidth * root.uiScale
            Layout.fillWidth: true

            Text {
                text: root.userName ? (root.greeting() + ", " + root.userName) : root.greeting()
                color: Colors.accent
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
                font.bold: true
            }

            Text {
                text: new Date().toLocaleTimeString(Qt.locale("es_ES"), "HH:mm")
                color: Colors.fg
                font.family: Colors.fontFamily
                font.pixelSize: 34 * root.uiScale
                font.bold: true
            }

            Text {
                text: root.cap1(new Date().toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM"))
                color: Colors.fg
                opacity: 0.65
                font.family: Colors.fontFamily
                font.pixelSize: 13 * root.uiScale
            }
        }

        DashboardCard {
            uiScale: root.uiScale
            tint: Colors.cpu
            Layout.preferredWidth: root.cardWidth * root.uiScale
            Layout.fillWidth: true

            Text {
                text: "Sistema"
                color: Colors.cpu
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                font.bold: true
            }

            DashboardInfoRow {
                Layout.fillWidth: true
                uiScale: root.uiScale
                icon: "\u{f17c}" // nf-fa-linux
                label: root.distro
            }

            DashboardInfoRow {
                Layout.fillWidth: true
                uiScale: root.uiScale
                icon: "\u{f108}" // nf-fa-desktop
                label: "Hyprland"
            }

            DashboardInfoRow {
                Layout.fillWidth: true
                uiScale: root.uiScale
                icon: "\u{f017}" // nf-fa-clock_o
                label: "up " + root.uptimeText
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14 * root.uiScale

        DashboardCard {
            uiScale: root.uiScale
            tint: Colors.memory
            Layout.preferredWidth: root.cardWidth * root.uiScale
            Layout.fillWidth: true

            Calendar {
                Layout.fillWidth: true
                uiScale: root.uiScale
                eventDayKeys: calEvents.eventDayKeys
            }
        }

        DashboardCard {
            uiScale: root.uiScale
            tint: Colors.network
            Layout.preferredWidth: root.cardWidth * root.uiScale
            Layout.fillWidth: true
            visible: calEvents.provider !== "none"

            TodayEvents {
                Layout.fillWidth: true
                uiScale: root.uiScale
                todayEvents: calEvents.todayEvents
                statusText: calEvents.statusText
            }
        }

        // Placeholder amigable cuando no hay calendario externo
        // configurado -- ocupa el mismo lugar que TodayEvents (arriba)
        // para que la grilla no se vea con un hueco, con una invitacion
        // clara a activarlo en vez de dejarlo vacio y confuso.
        DashboardCard {
            uiScale: root.uiScale
            tint: Colors.workspaceBorder
            Layout.preferredWidth: root.cardWidth * root.uiScale
            Layout.fillWidth: true
            visible: calEvents.provider === "none"

            Text {
                text: "Calendario externo"
                color: Colors.fg
                opacity: 0.5
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: "Opcional: conectá Outlook/Google/Nylas para ver tus eventos acá. Ver quickshell/scripts/CALENDAR.md."
                color: Colors.fg
                opacity: 0.55
                font.family: Colors.fontFamily
                font.pixelSize: 11 * root.uiScale
                wrapMode: Text.WordWrap
            }
        }
    }
}
