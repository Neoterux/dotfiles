# Scripts de estado de servidores

Esta carpeta guarda los scripts que alimentan la pestaña "Servers" del
dashboard (`modules/dashboard/ServersTab.qml`). Quickshell **no chequea
nada por la red**: solo lee un JSON. Un script tuyo (este directorio, o
uno corriendo en otra maquina) es quien hace los chequeos reales y
escribe ese JSON. Esta guía es para cuando quieras escribir uno nuevo o
adaptar el ejemplo.

## El contrato

`ServersTab.qml` lee, vía `FileView` con `watchChanges: true` (inotify,
sin polling):

```
~/.local/state/quickshell/servers.json
```

y espera un array de objetos:

| campo        | tipo   | obligatorio | notas |
|--------------|--------|:---:|-------|
| `name`       | string | sí  | único identificador visible en la tarjeta |
| `status`     | string | no  | `"up"` \| `"down"` \| `"degraded"`; cualquier otro valor (o ausente) cae a `"unknown"` |
| `url`        | string | no  | se muestra debajo del nombre si viene |
| `latencyMs`  | number | no  | se muestra como `"NNms"` si el campo existe |
| `checkedAt`  | string | no  | ISO 8601 (`date -u +%Y-%m-%dT%H:%M:%SZ`); se muestra como "hace Xm" |
| `note`       | string | no  | motivo si está down/degraded, o lo que quieras |

Cualquier campo extra en el objeto es ignorado, así que es seguro agregar
metadata propia sin romper el render.

**El único campo obligatorio es `name`** — todo el resto se omite en la
tarjeta si no viene, así que un script mínimo que solo resuelve up/down
sin latencia ni URL es perfectamente válido.

## Por qué el `mv` atómico importa

`ServersTab.qml` reacciona a cada escritura del archivo (`onTextChanged`).
Si el script escribe el JSON campo a campo directamente sobre
`servers.json`, hay una ventana real en la que Quickshell puede leer el
archivo a la mitad y toparse con JSON inválido (lo cual el código
tolera — cae a `root.servers = []`, no revienta — pero igual vas a ver
la pestaña vaciarse un instante en cada chequeo).

El patrón correcto, que ya usa `update-server-status.example.sh`, es:

```bash
OUT="$HOME/.local/state/quickshell/servers.json"
TMP="$(mktemp)"
mkdir -p "$(dirname "$OUT")"

# ... arma $TMP con el JSON completo ...

mv "$TMP" "$OUT"   # mv dentro del mismo filesystem es atómico
```

`mktemp` sin más argumentos cae en `/tmp` por defecto en la mayoría de
sistemas, que puede ser un filesystem distinto a `~/.local/state` (tmpfs
vs disco) — en ese caso `mv` deja de ser atómico porque el kernel hace
copy+unlink en vez de un rename. Si tu `/tmp` es un mount distinto,
generá el temporal en el mismo directorio que el destino:
`TMP="$(mktemp "$OUT.XXXXXX")"`.

## Cómo armar un script nuevo

1. **Copiá el ejemplo y sacale el `.example`**:
   ```bash
   cp scripts/update-server-status.example.sh scripts/update-server-status.sh
   chmod +x scripts/update-server-status.sh
   ```
   El ejemplo queda como plantilla de referencia sin wirear a nada — no
   lo edites in-place, así el próximo `git pull` no te pisa tu lista real
   de servidores.

2. **Definí tu lista de chequeos** y el método para cada uno (ver
   "Estrategias de chequeo" abajo — no todo es HTTP).

3. **Por cada servidor, calculá** `status`, `note` y opcionalmente
   `latencyMs` / `checkedAt`. Usá timeouts cortos y explícitos en cada
   chequeo (`--max-time`, `-W`, etc.) — un servidor colgado no debería
   hacer que el script entero tarde minutos en terminar.

4. **Serializá a un único array JSON** y escribilo con el patrón
   `TMP` → `mv` de arriba. `python3 -c 'import json; ...'` (como en el
   ejemplo) evita todos los problemas de escaping de armar JSON a mano
   en bash; `jq -n` es la alternativa si preferís no depender de python.

5. **Probalo a mano** antes de programarlo:
   ```bash
   ./scripts/update-server-status.sh
   jq . ~/.local/state/quickshell/servers.json
   ```
   y confirmá que la pestaña "Servers" del dashboard levanta los datos
   (no hace falta reiniciar Quickshell — `watchChanges` lo agarra solo).

6. **Programalo.** En esta máquina (Arch + systemd), preferí un timer de
   usuario en vez de cron:

   `~/.config/systemd/user/quickshell-server-status.service`:
   ```ini
   [Unit]
   Description=Actualiza servers.json para el dashboard de Quickshell

   [Service]
   Type=oneshot
   ExecStart=%h/dotfiles/v3/quickshell/scripts/update-server-status.sh
   ```

   `~/.config/systemd/user/quickshell-server-status.timer`:
   ```ini
   [Unit]
   Description=Corre update-server-status.sh cada 5 minutos

   [Timer]
   OnBootSec=1min
   OnUnitActiveSec=5min
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now quickshell-server-status.timer
   ```

   Ajustá `OnUnitActiveSec` al ritmo real que necesitás — igual que con
   los polls internos de Quickshell (ver `v3/CLAUDE.md`), no hay razón
   para chequear más seguido de lo que realmente te sirve enterarte.

## Estrategias de chequeo

El ejemplo solo hace `curl` a un endpoint HTTP, pero el contrato no sabe
ni le importa cómo llegaste al `status` — combiná lo que necesites:

**HTTP/HTTPS con código de estado** (lo que ya hace el ejemplo):
```bash
code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url")
[[ "$code" -ge 200 && "$code" -lt 400 ]] && status=up || status=degraded
```

**Puerto TCP abierto** (sin dependencias, bash puro vía `/dev/tcp`):
```bash
if timeout 3 bash -c ">/dev/tcp/$host/$port" 2>/dev/null; then
    status=up
else
    status=down
fi
```

**Ping simple** (solo confirma que el host responde, no un servicio):
```bash
if ping -c1 -W2 "$host" >/dev/null 2>&1; then status=up; else status=down; fi
```

**Comando remoto por SSH** (para chequear algo interno, ej. un servicio
systemd en otra máquina — necesita claves ya configuradas, sin prompt de
password):
```bash
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
    "systemctl is-active --quiet mi-servicio"; then
    status=up
else
    status=down
fi
```

**Contenedor Docker**:
```bash
state=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")
case "$state" in
    healthy) status=up ;;
    unhealthy) status=down ;;
    starting) status=degraded ;;
    *) status=unknown ;;
esac
```

Para latencia, medí solo lo que el chequeo mismo tarda
(`date +%s%3N` antes/después, como en el ejemplo) — no tiene sentido en
un chequeo de puerto/ping, es opcional.

## Chequeos hechos en otra máquina

Si el servidor a monitorear vive en otra red (ej. tu laburo) y esta
máquina no tiene línea directa, no fuerces la conexión desde acá: corré
el script de chequeo *allá* (mismo contrato, mismo formato de salida) y
sincronizá el `servers.json` resultante hacia
`~/.local/state/quickshell/servers.json` en esta máquina con lo que ya
uses (Syncthing, un `scp` en un timer, rsync sobre ssh). `ServersTab.qml`
no distingue el origen del archivo — si se actualiza, se refleja.

## Varios scripts, un solo archivo

El contrato es **un array plano en un solo archivo** — no hay
namespacing por script. Si vas a tener más de un checker (por ejemplo
uno para infra de trabajo y otro para tu homelab), no hagas que cada uno
pise `servers.json` con su propia lista parcial: vas a perder las
entradas del otro cada vez que corra cualquiera de los dos.

Dos formas válidas de resolverlo:
- Un único script "orquestador" que llama a las funciones de chequeo de
  cada fuente, junta todos los resultados en un solo array, y hace el
  único `mv` atómico al final (más simple, recomendado si todos corren
  en la misma máquina).
- Cada script escribe su propio JSON parcial en un archivo separado
  (`servers-work.json`, `servers-home.json`) y un tercer script/paso los
  mergea (`jq -s 'add' servers-*.json`) y escribe el `servers.json` final.
  Útil si las fuentes corren en máquinas distintas y llegan por
  sync en momentos distintos.

## Seguridad y secretos

Cualquier script que no termine en `.example.sh` en este directorio se
trackea en git igual que el resto del repo — no hay `.gitignore` acá.
Si tu lista real de servidores incluye URLs internas, tokens de auth
para health checks, o nombres de host que no querés públicos, o bien:
- agregá una entrada a `.gitignore` para tu script real antes de
  commitear nada, o
- guardá la lista de servidores en un archivo separado fuera del repo
  (ej. `~/.config/quickshell-servers.env`) y que el script solo la
  lea (`source`), quedando el script trackeado genérico y los datos
  sensibles afuera.

## Debug

- `jq . ~/.local/state/quickshell/servers.json` — confirmá que el JSON
  es válido y tiene la forma esperada antes de sospechar de la UI.
- Si la pestaña muestra "sin datos" con el archivo ya poblado: revisá
  que sea un array en la raíz (`[...]`), no un objeto — `ServersTab.qml`
  descarta cualquier cosa que no pase `Array.isArray`.
- `status` fuera de `up|down|degraded` no es un error, cae a `unknown`
  silenciosamente (gris) — útil como default seguro, pero si esperabas
  ver rojo/verde y ves gris, revisá que estés escribiendo el string
  exacto.
