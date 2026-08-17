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
| `engine`     | string | no  | se muestra como etiqueta naranja al lado de la URL (`postgres`, `redis`, ...) |
| `metrics`    | array  | no  | indicadores para la grilla de la tarjeta, ver abajo |

Cada objeto de `metrics` es:

| campo   | tipo   | obligatorio | notas |
|---------|--------|:---:|-------|
| `label` | string | sí  | texto corto; hay ~119px por celda, no entra una frase |
| `value` | string | sí  | ya formateado para mostrar (`"42/100"`, `"1.2G"`, `"98.3%"`) |
| `level` | string | no  | `"ok"` \| `"warn"` \| `"crit"`; solo warn/crit se colorean |
| `ratio` | number | no  | 0..1; agrega la barrita de uso debajo del valor |

La tab **no sabe nada de bases de datos**: solo dibuja label/value y
colorea según `level`. Cualquier checker (HTTP, colas, disco de un NAS)
puede llenar `metrics` sin tocar el QML. `ratio` solo tiene sentido en
métricas que son "usado de un máximo" — es lo que dibuja la barra.

Nota de diseño: `"ok"` **no** se colorea de verde a propósito. Si todos
los valores sanos se pintaran, la tarjeta sería un arcoíris y el
indicador que importa se perdería entre los demás; con solo warn/crit
coloreados, lo que está mal salta a la vista sin leer nada.

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

## Checker de bases de datos (`check-db-servers.py`)

Ya hay uno hecho para el caso más común: chequear servidores de BDD.
A diferencia de `update-server-status.example.sh` (que es una plantilla
para copiar y editar), este es un script terminado y genérico — la lista
de servidores no vive adentro sino en un JSON de config **fuera del
repo**, así que se usa tal cual está y no filtra hosts ni credenciales.

```bash
mkdir -p ~/.config/quickshell
cp scripts/db-servers.example.json ~/.config/quickshell/db-servers.json
$EDITOR ~/.config/quickshell/db-servers.json   # tu lista real
scripts/check-db-servers.py --print            # probar sin escribir nada
scripts/check-db-servers.py                    # escribir servers.json
```

Solo usa stdlib (nada de `pip install`), y delega el chequeo real a los
clientes de línea de comandos de cada motor:

| `engine`             | usa                       | detecta además de up/down |
|----------------------|---------------------------|---------------------------|
| `postgres`           | `pg_isready`              | `degraded` si acepta TCP pero rechaza conexiones (recovery, max_connections) |
| `mysql` / `mariadb`  | `mariadb-admin ping`      | `degraded` si contesta el handshake pero rechaza credenciales, o "too many connections" |
| `redis`              | `redis-cli PING`          | `degraded` en NOAUTH/WRONGPASS o mientras carga el dataset |
| `mongodb`            | `mongosh` + `ping`        | `degraded` si falla la autenticación |
| `docker`             | `docker inspect`          | usa el healthcheck del contenedor (`starting` → degraded) |
| `tcp`                | socket, sin cliente       | solo puerto abierto — para motores sin cliente instalado (Oracle, MSSQL) |
| `http` / `https`     | `urllib` (stdlib)         | código, contenido, campo del JSON de health, vencimiento del cert TLS — ver abajo |

Si el cliente del motor no está instalado, cae solo a chequeo de puerto
TCP y lo aclara en la nota de la tarjeta, en vez de reportar `unknown`.

### Webapps y endpoints HTTP

El motor `http` (alias `https` y `webapp`) chequea una webapp. A diferencia
de una BDD, que conteste no alcanza: una app puede devolver 200 con la
página de error adentro, o redirigir al login. Por eso además del código se
puede exigir contenido:

```jsonc
{
  "name": "api-health",
  "engine": "http",
  "url": "https://api.example.com/health",
  "json_path": "status",      // acepta rutas anidadas: "deps.db"
  "json_equals": "ok",
  "slow_ms": 800
}
```

| campo | default | qué hace |
|---|---|---|
| `url` | — | obligatorio, con esquema (`https://…`) |
| `method` | `GET` | `HEAD` saltea los chequeos de contenido en vez de fallarlos |
| `expect_status` | 200-399 | `200`, `[200,204]` o `"2xx"` |
| `expect_body` | — | substring que tiene que aparecer |
| `json_path` / `json_equals` | — | campo del JSON de health y su valor esperado |
| `headers` | — | headers extra |
| `token_env` / `token_cmd` / `token` | — | manda `Authorization: Bearer <token>` |
| `user` + `password_*` | — | basic auth, mismo orden de secretos que las BDD |
| `cert_warn_days` | `14` | `degraded` si el cert TLS vence antes; `false` lo apaga |
| `follow_redirects` | `true` | `false` para evaluar el 3xx en vez de seguirlo |
| `insecure` | `false` | no validar el certificado (self-signed) |

**Cómo se decide el status:**

- Código dentro de `expect_status` y contenido que matchea → `up`
- **5xx** → `down` (la app contesta pero está rota)
- **4xx** inesperado → `degraded` — está viva; lo que está mal es la ruta o
  la auth del chequeo, que es tanto un problema del monitoreo como del
  servicio, y marcarlo `down` te haría buscar el problema donde no está
- Contenido que no matchea (`expect_body`, `json_equals`, respuesta que no
  es JSON) → `degraded`
- Certificado por vencer → `degraded`; inválido, vencido o de otro host →
  `down` con el motivo en la nota
- DNS, conexión rechazada o timeout → `down`

Solo lee los primeros 64KB de la respuesta — un health endpoint devuelve
unos cientos de bytes y no tiene sentido bajarse la SPA entera en cada
corrida del timer.

El chequeo del certificado abre una segunda conexión TLS (~50ms) porque
`urllib` no expone el cert del socket que usó para la request. Si te molesta
en un chequeo muy frecuente, `"cert_warn_days": false`.

### Métricas

Además del up/down, cada chequeo junta indicadores y los manda en
`metrics`. Un up/down solo avisa cuando ya es tarde; esto es lo que deja
ver el problema viniendo:

| motor      | métricas |
|------------|----------|
| `postgres` | conexiones usadas/max (con barra), consultas activas, tamaño de la base, cache hit ratio, replication lag y rol (primary/replica), duración de la consulta más larga, uptime |
| `mysql`    | conexiones usadas/max, threads corriendo, hit ratio del buffer pool de InnoDB, replication lag (con `"replication": true`), slow queries, conexiones abortadas, uptime |
| `redis`    | clientes conectados/max, memoria usada (barra contra `maxmemory`), hit ratio del keyspace, cantidad de claves, claves evictadas, estado del link de replicación y rol, uptime |
| `mongodb`  | conexiones usadas/total, tamaño de la base, memoria residente, operaciones encoladas, rol en el replica set, uptime |
| `docker`   | uptime del contenedor y cantidad de restarts |
| `http`     | código HTTP, tamaño de la respuesta, días hasta que vence el cert TLS, y el valor de `json_path` si es escalar |

En los motores de BDD las métricas son un chequeo aparte del ping y
**necesitan credenciales con permiso de lectura** (en mongo, rol
`clusterMonitor`); en `http` salen del mismo request, sin costo extra
salvo el cert. Si no las
tenés configuradas, el chequeo up/down sigue andando igual y la tarjeta
simplemente no muestra la grilla — no se rompe ni se marca en rojo. Ese
aviso se calla a propósito salvo que pongas `"metrics": true` explícito
en esa entrada: con el default implícito saldría en cada tarjeta y cada
corrida, y sería puro ruido.

Umbrales que colorean el valor (y dibujan la barra):

- **conexiones**: ≥75% `warn`, ≥90% `crit`
- **replication lag**: ≥10s `warn`, ≥60s `crit`
- **link de replicación caído**: `crit`
- **código HTTP**: `crit` si es 5xx, `warn` si cayó fuera de
  `expect_status` sin ser 5xx (un 404 que vos pediste con
  `"expect_status": 404` queda `ok`, no baja la tarjeta)
- **cert TLS**: `warn` a 30 días, `crit` en tu `cert_warn_days` — el mismo
  umbral que baja el status, para que color y estado digan lo mismo
- **cache/buffer hit ratio**: <90% `warn`, nunca `crit` — es una señal de
  performance, no un servicio caído. Además, con menos de 1000 accesos
  acumulados se muestra sin color: una base recién levantada da 7% de hit
  ratio y no tiene absolutamente nada malo.
- **memoria de redis contra `maxmemory`**: ≥75% `warn`, ≥90% `crit`
- **restarts de un contenedor**: ≥1 `warn`, ≥5 `crit`
- **contadores acumulados** (slow queries, evictions, conexiones
  abortadas): en cero no se muestran, y cuando existen van **sin color**.
  Son totales desde que arrancó el server, no un estado actual: con
  `warn` quedaban amarillos para siempre (8 slow queries en 11 días no es
  un problema) y el color que no se apaga nunca termina enseñándole al
  ojo a ignorar el amarillo. El dato sirve por su tendencia, que la
  tarjeta no puede mostrar.

La métrica `query+` de postgres (consulta activa más larga) filtra por
`backend_type='client backend'`, o sea que **necesita PG 10+**. El filtro
no es opcional: sin él entran los procesos internos (walsender,
autovacuum launcher), que figuran como `active` con el `query_start` del
arranque del servidor — contra producción eso daba `query+ 40d` en
crítico, donde 40 días era el uptime y no una consulta colgada.

Una métrica en `crit` baja el status a `degraded` aunque el servidor siga
contestando — si no, una BDD al tope de conexiones se vería verde y
habría que leerle la letra chica a la tarjeta. Se apaga por entrada con
`"metrics_degrade": false`.

Para desactivar la recolección: `"metrics": false` en una entrada, o
`--no-metrics` para toda la corrida (útil para ver rápido si algo está
vivo sin pegarle consultas a nada).

### Métricas propias (`custom_metrics`)

Las métricas de arriba son las que sirven para cualquier base. Para lo que
es tuyo — pedidos de la última hora, largo de una cola, filas en una tabla
de trabajos — hay `custom_metrics` por entrada:

```jsonc
"custom_metrics": [
  { "label": "tx/s",    "sql": "SELECT sum(xact_commit+xact_rollback) FROM pg_stat_database",
                        "rate": true },
  { "label": "locks",   "sql": "SELECT count(*) FROM pg_locks WHERE NOT granted",
                        "warn": 1, "crit": 10, "degrade": true },
  { "label": "pedidos", "sql": "SELECT count(*) FROM pedidos WHERE creado > now() - interval '1 hour'",
                        "suffix": "/h" }
]
```

De dónde sale el valor, según el motor:

| motor | campo | ejemplo |
|---|---|---|
| `postgres` / `mysql` / `mariadb` | `sql` | `SELECT count(*) FROM pedidos` |
| `redis` | `command` | `LLEN cola:mails` |
| `mongodb` | `eval` | `db.pedidos.countDocuments({})` |
| `http` | `json_path` | `queue.pending` |

Modificadores, todos opcionales:

| campo | qué hace |
|---|---|
| `format` | `auto` (default), `number`, `bytes`, `duration`, `percent` (espera 0..1), `text` |
| `suffix` | se pega al valor (`"/h"`, `" req"`) |
| `warn` / `crit` | colorean el valor |
| `invert` | `true` si MENOS es peor (hit ratios) |
| `max` | dibuja la barrita: `ratio = valor / max` |
| `rate` | contador acumulado → lo muestra por segundo |
| `degrade` | `true` para que un `crit` baje el status |

**Un `crit` custom no baja el status, salvo que pongas `degrade: true`.**
`pedidos > 500` es una métrica de negocio: un día de ventas bueno no es una
base de datos degradada, y si el punto de la tarjeta se pone amarillo por
eso, el indicador de salud deja de significar salud. Las que sí miden salud
(locks sin otorgar, una cola que no se vacía) llevan `degrade: true`.

**`rate` para contadores.** El total acumulado de un contador desde que
arrancó el server (`847392091` queries) no dice nada en una tarjeta; lo que
importa es cuánto se movió por segundo. Con `"rate": true` el script guarda
el valor en el propio `servers.json` (clave `_counters`, que el QML ignora)
y en la corrida siguiente resta contra él — sin estado en ningún otro lado.
La primera corrida no muestra nada porque todavía no hay contra qué restar,
y si el server se reinicia y el contador vuelve a cero, esa vuelta se
omite en vez de mostrar un negativo.

**Tu SQL corre acotado.** Antes de la consulta, en la misma sesión, el
script hace `SET default_transaction_read_only=on` y
`SET statement_timeout='3s'` (en mysql, `max_execution_time` /
`max_statement_time` + `SET SESSION TRANSACTION READ ONLY`). Corre con las
credenciales que configuraste contra tu base real: un `DELETE` por typo o
un `count(*)` sin índice sobre una tabla grande, cada 5 minutos, es un
problema de verdad. Con el corralito, un intento de escritura falla con
"cannot execute ... in a read-only transaction" y aparece como métrica sin
datos.

**Una consulta, un valor.** Cada `sql` se envuelve como subconsulta escalar
(`SELECT (tu consulta)`), así que si devuelve más de una fila o columna el
motor tira un error claro en vez de que te quedes mirando el primer campo
sin saber qué estás viendo.

**Una consulta rota no arrastra a las demás.** Las métricas custom van en
una pasada aparte de las built-in, y dentro de esa pasada cada consulta va
separada por marcadores: la que falla no escribe nada y se identifica sola.
Todo en **una sola conexión** por servidor, no una por métrica (salvo redis,
donde `redis-cli` toma un comando por corrida y una conexión cuesta ~1ms).
Si pusiste `"metrics": true` explícito, las que fallaron salen listadas en
la nota de la tarjeta.

El tiempo de las consultas custom **no** cuenta para `latencyMs` ni para
`slow_ms` — si no, una consulta tuya pesada marcaría el servidor como lento
cuando el que tarda es tu `count(*)`.

### Secretos con Bitwarden CLI

`password_cmd` y `token_cmd` corren cualquier comando, así que `bw` entra
directo:

```json
{
  "name": "pg-prod",
  "engine": "postgres",
  "host": "db.interno.example",
  "user": "monitor",
  "password_cmd": "bw get password 'PG Monitor' --raw --nointeraction"
}
```

**`--nointeraction` no es opcional.** Sin ese flag y con el vault
bloqueado, `bw` manda el prompt de la master password a stderr, deja
stdout vacío y **sale con código 0**:

```console
$ bw get password loquesea </dev/null >salida 2>error; echo "exit=$?"
exit=0
$ wc -c < salida        # stdout: solo un \n
1
$ cat error
? Master password: [input is hidden]
```

Un exit 0 con stdout vacío es la peor combinación posible para un
resolvedor de secretos: parece éxito. Por eso `resolve_secret` **exige
salida no vacía además del exit 0** — si no, esa cadena vacía se tomaría
como contraseña válida y cortaría la cadena de fallback sin llegar nunca
al `password` de respaldo, dejando el chequeo fallando por "access denied"
sin una pista del motivo real.

Aun con esa defensa, poné el flag: sin él seguís pagando ~1.3s por secreto
en vez de ~300ms, y si corrés el script a mano (con stdin conectado a la
terminal) `bw` se queda esperando la master password hasta el timeout de
10s. Con `--nointeraction` falla como corresponde:

```console
$ bw get password loquesea --nointeraction; echo "exit=$?"
Vault is locked.
exit=1
```

Ahí `resolve_secret` ve el exit ≠ 0, descarta la salida y sigue al
siguiente método. `--raw` es para que devuelva el valor pelado, sin el
mensaje descriptivo alrededor.

**El vault tiene que estar desbloqueado.** `bw` necesita una session key
en `BW_SESSION` (o vía `--session`), y **un timer de systemd no hereda tu
shell** — sin eso, cada corrida falla con "Vault is locked" y todas las
tarjetas quedan en `degraded` a la vez. Para desbloquear:

```bash
export BW_SESSION=$(bw unlock --raw)     # pide la master password una vez
```

Esa key vale hasta que corras `bw lock`, cierres sesión, o hagas otro
`bw unlock` (que invalida las anteriores).

**Un `bw` por secreto sale caro.** Cada invocación es un proceso de Node:
~1.3s cuando trabaja, ~300ms cuando falla rápido. Con `password_cmd` el
script lo llama **una vez por servidor**, en paralelo, en **cada corrida
del timer**. Con 6 entradas del mismo vault eso son 6 procesos de Node
cada 5 minutos para traer 6 secretos que no cambian.

Si tenés más de un par de entradas, conviene resolver todo una vez y pasar
las credenciales por entorno con `password_env` / `token_env`:

```bash
#!/usr/bin/env bash
# check-with-bw.sh -- desbloquea una vez, resuelve los secretos y corre el
# checker. Es lo que apunta el ExecStart del timer.
set -euo pipefail

# La master password sale de otro lado (el keyring del escritorio, por
# ejemplo) para que el timer no dependa de que vos hayas exportado nada.
export BW_SESSION="$(secret-tool lookup service bitwarden account master \
    | bw unlock --raw --passwordfile /dev/stdin)"

bw sync --nointeraction >/dev/null   # opcional, si rotás credenciales seguido

get() { bw get password "$1" --raw --nointeraction; }

export PG_MONITOR_PASSWORD="$(get 'PG Monitor')"
export API_MONITOR_TOKEN="$(get 'API Monitor Token')"

exec "$(dirname "$0")/check-db-servers.py" "$@"
```

y en el config, `"password_env": "PG_MONITOR_PASSWORD"` en vez de
`password_cmd`. Un solo `bw unlock` y un `bw get` por secreto distinto, no
por servidor.

> Ojo con `set -x` y con hacer que el wrapper loguee a un archivo: las
> credenciales salen en claro. Y si el vault está bloqueado, el `set -e`
> corta el wrapper antes de correr el checker — el `servers.json` queda con
> los datos de la corrida anterior y la tarjeta va a decir "hace 20m" en vez
> de marcarse caída. Ese "hace Xm" creciendo es la señal de que el wrapper
> está fallando, no los servidores.

Si el ida y vuelta con la session key te resulta incómodo,
[`rbw`](https://github.com/doy/rbw) (cliente no oficial, en Rust) tiene un
agente que mantiene el vault abierto y no necesita `BW_SESSION`:
`rbw get 'PG Monitor'` y listo. No está instalado en esta máquina.

### Detalles que importan

- **Credenciales**: preferí `password_env` (nombre de una env var) o
  `password_cmd` (un comando que la imprime, ej. `pass show db/prod`, o
  Bitwarden — ver abajo). Hay un campo `password` en texto plano pero es
  el último recurso — el config está fuera del repo, pero igual queda en
  disco sin cifrar.
- **`slow_ms`**: si el servidor responde pero tarda más que ese umbral,
  la entrada pasa a `degraded`. Sirve para enterarte de que algo se está
  degradando *antes* de que se caiga del todo.
- **Paralelo**: todos los chequeos corren en un thread pool (`-j`, 8 por
  defecto), así un servidor colgado no le suma su timeout al resto.
- **Merge**: por defecto conserva las entradas de `servers.json` que no
  escribió él (las marca con `"source": "db-checker"`, campo que la UI
  ignora), así convive con otros checkers sin pisarlos — es la primera de
  las dos estrategias de "Varios scripts, un solo archivo" de más abajo,
  ya resuelta. `--no-merge` para pisar el archivo entero.
- **Exit code**: siempre 0 si el chequeo corrió, aunque haya servidores
  caídos — un server down es el resultado esperado, no una falla del
  script, y si devolviera != 0 systemd marcaría el timer como `failed`
  justo cuando más te importa que siga corriendo. Los exit 1 son solo
  errores de config o de uso.

### Correrlo de forma indefinida

Sin argumentos hace **una pasada y termina** — que es exactamente lo que
quiere un timer de systemd. Con `--interval` se queda corriendo:

```bash
scripts/check-db-servers.py --interval 5m     # 30, 30s, 5m, 1h
```

Tres cosas lo hacen sobrevivir sin niñera:

- **Relee el config en cada vuelta**: agregar o sacar servidores no
  requiere reiniciarlo. Y si lo dejás a medio editar justo cuando toca
  chequear, se queja en stderr y **sigue con la lista anterior** en vez de
  morirse.
- **Una vuelta que revienta no mata el proceso**: disco lleno, DNS caído,
  un cliente que segfaultea — lo loguea y sigue en la siguiente.
- **`SIGTERM`/`SIGINT` cortan limpio** en menos de un segundo, así
  `systemctl --user stop` no tiene que mandar `SIGKILL`.

El período descuenta lo que tardó la corrida, así que no se va corriendo
de a poco en cada vuelta.

Como servicio de usuario
(`~/.config/systemd/user/quickshell-server-status.service`):

```ini
[Unit]
Description=Estado de servidores para el dashboard de Quickshell

[Service]
Type=simple
ExecStart=%h/dotfiles/v3/quickshell/scripts/check-db-servers.py --interval 5m
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now quickshell-server-status
journalctl --user -u quickshell-server-status -f
```

**Cuál de los dos conviene: el timer, salvo que tengas una razón.** Un
daemon en Python ocupa ~32 MB residentes todo el tiempo para hacer algo
que dura dos segundos cada cinco minutos; el timer no ocupa nada entre
corridas, que en una barra que también corre Quickshell no es un detalle
menor (ver la nota de recursos en `v3/CLAUDE.md`). `--interval` es para
cuando no querés meter unidades de systemd, para correrlo a mano en una
terminal mientras mirás algo, o para una máquina donde el timer no es una
opción.

Para el timer, el mismo de la sección de abajo, cambiando el `ExecStart` a
`%h/dotfiles/v3/quickshell/scripts/check-db-servers.py` (sin
`--interval`). Si usás `password_env`, acordate de que ni el timer ni el
servicio heredan tu shell: pasá la variable con `Environment=` en el
`.service` o usá `password_cmd`.

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

**HTTP/HTTPS con código de estado** (lo que hace el ejemplo en bash):
```bash
code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url")
[[ "$code" -ge 200 && "$code" -lt 400 ]] && status=up || status=degraded
```

> Para webapps normalmente no hace falta escribir esto: el motor `http` de
> `check-db-servers.py` ya lo hace, y además chequea contenido, campos del
> JSON de health y vencimiento del certificado. Este snippet queda para
> cuando estés armando un script propio desde cero.

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
