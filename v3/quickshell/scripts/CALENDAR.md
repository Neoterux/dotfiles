# Calendario externo (pestaña "Dashboard")

`modules/dashboard/CalendarEvents.qml` agrega eventos de un calendario
externo a la grilla del Dashboard (puntito en el día + lista "Hoy").
Igual que `servers.json` (ver `README.md`), Quickshell **no se conecta a
nada por su cuenta** salvo que lo configures: sin config, el calendario
sigue andando, solo que sin eventos.

## El contrato

`CalendarEvents.qml` lee, vía `FileView` con `watchChanges: true`:

```
~/.local/state/quickshell/calendar.json
```

```json
{
  "provider": "ics",
  "ics": {
    "url": "https://.../calendar.ics",
    "username": "",
    "password": ""
  },
  "nylas": { "apiKey": "", "grantId": "", "region": "us" }
}
```

| campo             | notas |
|--------------------|-------|
| `provider`         | `"ics"` \| `"nylas"` \| `"none"`/ausente (sin eventos) |
| `ics.url`          | URL http(s) **o** ruta local (`/ruta`, `~/ruta`, `file:///ruta`) |
| `ics.username`/`.password` | opcionales, HTTP Basic Auth (lo que pide DavMail) |
| `nylas.apiKey`/`.grantId`/`.region` | credenciales de Nylas v3 (`region`: `"us"` o `"eu"`) |

Se refresca solo cada 15 minutos (Timer interno) o al editar el archivo
(`watchChanges`, no hace falta reiniciar Quickshell). Ver
`calendar.example.json` en esta carpeta para copiar como punto de
partida.

## Opción A — ICS público (Google Calendar, Outlook con "publicar
calendario")

La más simple: tanto Google Calendar como Outlook.com/Office 365 tienen
una opción en la configuración del calendario para generar una URL
`.ics` pública o "secreta" (con un token largo en la URL, no indexada
pero sin login). Pegala directo en `ics.url`, dejá `username`/`password`
vacíos.

- Google Calendar: Configuración → tu calendario → "Integrar calendario"
  → "Dirección secreta en formato iCal".
- Outlook.com: Configuración → Calendario → "Calendarios compartidos" →
  "Publicar un calendario" → copiar el enlace ICS.

No sirve para Exchange/Outlook corporativo si el admin desactivó la
publicación pública — para eso, ver la Opción B.

## Opción B — Outlook/Exchange corporativo vía DavMail

Si tu Outlook es Exchange/Office 365 gestionado por tu empresa (sin
"publicar calendario" habilitado), [DavMail](http://davmail.sourceforge.net/)
es un gateway que habla EWS/OWA con el servidor de Exchange y expone
IMAP/SMTP/CalDAV/LDAP localmente. Acá interesa el puerto CalDAV.

### 1. Instalar y configurar DavMail

```bash
yay -S davmail   # o el paquete que corresponda a tu distro
```

Config mínima (`~/.davmail.properties`, o vía la UI si corrés
`davmail` sin flags la primera vez):

```properties
davmail.mode=EWS
davmail.url=https://outlook.office365.com/EWS/Exchange.asmx
davmail.server=true
davmail.caldavPort=1080
davmail.disableUpdateCheck=true
```

`davmail.url` es el endpoint EWS de tu organización — para Office 365 es
el de arriba; para Exchange on-prem, preguntale a IT o mirá la
configuración de Outlook (Cuenta → Configuración avanzada → EWS URL).

Corré `davmail` (o encendé el servicio si el paquete trae uno) y dejalo
corriendo en background — necesita estar vivo para que Quickshell (o
vdirsyncer, ver abajo) le pueda pegar.

### 2. Encontrar la URL del calendario

Con DavMail corriendo, tu calendario CalDAV queda en:

```
http://localhost:1080/users/tu.email@empresa.com/calendar/
```

Confirmalo con un cliente CalDAV cualquiera (Thunderbird, o
`curl --basic -u 'tu.email@empresa.com:tu-contraseña' http://localhost:1080/users/tu.email@empresa.com/calendar/`)
antes de asumir que el path es exactamente ese — varía un poco según
versión de DavMail y del servidor.

### 3a. Intento directo (probalo primero)

Algunas versiones de DavMail responden a un `GET` simple sobre esa URL
con contenido `text/calendar` usable tal cual. Si es tu caso, es la
opción más simple:

```json
{
  "provider": "ics",
  "ics": {
    "url": "http://localhost:1080/users/tu.email@empresa.com/calendar/",
    "username": "tu.email@empresa.com",
    "password": "tu-contraseña-o-app-password"
  }
}
```

**Esto no está verificado en vivo en este repo** (no hay una cuenta
Exchange real disponible para probarlo) — CalDAV "de verdad" espera un
método `REPORT` con un body XML (`calendar-query`), no un `GET` plano,
así que el comportamiento exacto depende de la implementación de tu
servidor/DavMail. Si el `GET` no devuelve nada usable (0 eventos, error,
o HTML en vez de texto ICS), pasá a la opción 3b.

### 3b. Alternativa confiable — vdirsyncer a un archivo local

[`vdirsyncer`](https://vdirsyncer.pimutils.org/) es la herramienta
estándar para sincronizar CalDAV a `.ics` locales, y sí hace el
`REPORT` de verdad (no depende de que el servidor responda bien a un
`GET` suelto).

```bash
yay -S vdirsyncer   # o pip install --user vdirsyncer
```

`~/.config/vdirsyncer/config`:

```ini
[general]
status_path = "~/.vdirsyncer/status/"

[pair calendar]
a = "calendar_local"
b = "calendar_remote"
collections = ["from b"]

[storage calendar_local]
type = "filesystem"
path = "~/.local/share/vdirsyncer/calendar/"
fileext = ".ics"

[storage calendar_remote]
type = "caldav"
url = "http://localhost:1080/users/tu.email@empresa.com/calendar/"
username = "tu.email@empresa.com"
password.fetch = ["command", "cat", "/home/tu-usuario/.vdirsyncer-pass"]
```

(Guardá la contraseña en un archivo aparte con permisos `600` en vez de
en el config, o usá `password_command` con tu gestor de secretos si
preferís no tener texto plano en disco.)

```bash
vdirsyncer discover calendar
vdirsyncer sync
```

Esto deja archivos `.ics` individuales (uno por evento) en
`~/.local/share/vdirsyncer/calendar/<collection>/` — no es el único
archivo combinado que necesita `CalendarEvents.qml`. Concatenalos con un
timer, matching el patrón `TMP` → `mv` atómico que ya usa
`update-server-status.example.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SRC="$HOME/.local/share/vdirsyncer/calendar"
OUT="$HOME/.local/state/quickshell/calendar-merged.ics"
TMP="$(mktemp "$OUT.XXXXXX")"
mkdir -p "$(dirname "$OUT")"

{
    echo "BEGIN:VCALENDAR"
    echo "VERSION:2.0"
    find "$SRC" -name '*.ics' -exec sed -n '/^BEGIN:VEVENT/,/^END:VEVENT/p' {} \;
    echo "END:VCALENDAR"
} > "$TMP"
mv "$TMP" "$OUT"
```

Programá `vdirsyncer sync` + este merge con un timer de systemd --user
(mismo patrón que la sección "Programalo" en `README.md`, cada 15-30min
alcanza). Después, en `calendar.json`:

```json
{
  "provider": "ics",
  "ics": { "url": "~/.local/state/quickshell/calendar-merged.ics" }
}
```

`ics.url` sin `http://`/`https://` al inicio se trata como archivo
local (soporta `~/...`, `/ruta/absoluta`, o `file:///ruta`) — se lee con
`FileView` en vez de una request de red, y se re-lee solo apenas el
archivo cambia (`watchChanges`), sin depender del timer de 15min interno
para verlo.

## Opción C — Nylas (no verificado)

Implementado contra la forma documentada de la API v3 de Nylas
(`GET https://api.<region>.nylas.com/v3/grants/{grantId}/events`, header
`Authorization: Bearer <apiKey>`) pero no hay cuenta real disponible en
este repo para probarlo en vivo. Si armás una cuenta Nylas y conectás tu
Outlook/Gmail ahí (Nylas maneja el OAuth por vos), completá:

```json
{
  "provider": "nylas",
  "nylas": { "apiKey": "nyk_...", "grantId": "...", "region": "us" }
}
```

Si algo no matchea (campos distintos, paginación, formato de fecha),
es lo primero a revisar contra la [documentación actual de Nylas](https://developer.nylas.com/docs/api/v3/ecc/#tag/events)
— la API puede haber cambiado desde que se escribió esto.

## Debug

- Mirá `eventsStatusText` en la UI (aparece bajo la lista "Hoy") —
  cualquier error de fetch/parseo queda ahí, no solo en un log.
- Para un archivo local: `cat` el path exacto que pusiste en `ics.url`
  (con `~` ya expandido a mano) y confirmá que el proceso de Quickshell
  tiene permiso de lectura.
- Para DavMail: confirmá primero que DavMail está vivo y el puerto
  CalDAV responde (`curl -v --basic -u user:pass
  http://localhost:1080/users/tu.email/calendar/`) *antes* de sospechar
  de Quickshell — si `curl` ya no trae nada útil, el problema está en
  DavMail/vdirsyncer, no en `CalendarEvents.qml`.
- RRULE (eventos recurrentes) no se expande en ningún proveedor ICS —
  vas a ver el primer horario del evento, no cada repetición futura. Si
  necesitás eso, expandí el RRULE en el script que genera el `.ics`
  final (vdirsyncer no lo hace por vos tampoco) antes de que
  `CalendarEvents.qml` lo lea.
