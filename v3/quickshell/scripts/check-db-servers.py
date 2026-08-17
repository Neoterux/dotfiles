#!/usr/bin/env python3
"""Chequea servidores de base de datos y escribe el JSON que lee la pestaña
"Servers" del dashboard de Quickshell (modules/dashboard/ServersTab.qml).

Solo stdlib -- no instala nada. Los chequeos "de verdad" se delegan a los
clientes de linea de comandos de cada motor (pg_isready/psql, mariadb,
redis-cli, mongosh, docker); si el cliente no esta instalado, cae a un
chequeo de puerto TCP y lo aclara en la nota de la tarjeta.

Ademas del up/down, junta metricas por motor (conexiones usadas vs max,
tamaño, cache hit ratio, replication lag, uptime, memoria) y las manda en
el campo `metrics` del contrato, que la tarjeta renderiza como grilla de
indicadores. Un up/down solo te avisa cuando ya es tarde; estas metricas
son las que te dejan ver el problema viniendo.

La lista de servidores NO vive aca: vive en un JSON de config, por defecto
en ~/.config/quickshell/db-servers.json (fuera del repo, ver
db-servers.example.json al lado de este script). Asi este script queda
trackeado en git sin filtrar hosts internos ni credenciales.

Uso:
    ./check-db-servers.py                  # chequea y escribe servers.json
    ./check-db-servers.py --print          # solo imprime, no toca el archivo
    ./check-db-servers.py --only prod-db   # chequea una sola entrada
    ./check-db-servers.py --interval 5m    # corre indefinidamente (daemon)
    ./check-db-servers.py -c otra.json -o /tmp/salida.json

El archivo final se escribe con os.replace() (rename atomico, mismo
directorio) para que ServersTab.qml -- que mira el archivo con
FileView.watchChanges -- nunca lo lea a la mitad.
"""

import argparse
import base64
import json
import os
import shlex
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from urllib.parse import urlparse

DEFAULT_CONFIG = os.path.expanduser("~/.config/quickshell/db-servers.json")
DEFAULT_OUT = os.path.expanduser("~/.local/state/quickshell/servers.json")

# Marca las entradas escritas por este script. Al hacer merge se reemplazan
# solo las propias y se respetan las que haya puesto otro checker (ver
# "Varios scripts, un solo archivo" en el README). ServersTab.qml ignora
# cualquier campo extra, asi que este campo no afecta el render.
SOURCE_TAG = "db-checker"

DEFAULT_PORTS = {
    "postgres": 5432,
    "mysql": 3306,
    "mariadb": 3306,
    "redis": 6379,
    "mongodb": 27017,
    "mssql": 1433,
}

# Motores que no necesitan 'port': docker mira un contenedor y http
# saca host y puerto de la url.
PORTLESS_ENGINES = ("docker", "http", "https", "webapp")

DEFAULT_TIMEOUT = 5.0


# --------------------------------------------------------------------------
# helpers generales
# --------------------------------------------------------------------------

def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def resolve_password(srv):
    """Password del servidor. Ver resolve_secret para el orden."""
    return resolve_secret(srv, "password")


def run(cmd, timeout, env=None):
    """Corre un comando y devuelve (returncode, stdout+stderr).

    returncode None == se colgo y lo matamos por timeout.
    """
    full_env = None
    if env:
        full_env = os.environ.copy()
        full_env.update({k: v for k, v in env.items() if v is not None})

    try:
        # stdin cerrado a proposito: varios clientes (psql sobre todo)
        # piden la password por teclado cuando no la encuentran, y con el
        # stdin heredado del timer se quedan colgados hasta el timeout en
        # vez de fallar al instante.
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, env=full_env,
            stdin=subprocess.DEVNULL,
        )
    except subprocess.TimeoutExpired:
        return None, ""
    except (OSError, ValueError) as exc:
        return -1, str(exc)

    return proc.returncode, (proc.stdout + proc.stderr).strip()


# Ruido que los clientes escupen por stderr y que no dice nada del estado
# del servidor -- si queda como nota, tapa el error real en la tarjeta.
NOISE_PREFIXES = (
    "deprecated program name",
    "warning:",
    "check that",
    "you can check this",
    "$ mongosh",
    "for more information",
)


def pick_error_line(out, fallback="sin respuesta"):
    """Saca la linea util de la salida de un cliente para usar como nota."""
    lines = []
    for raw in out.splitlines():
        line = raw.strip()
        if not line:
            continue
        low = line.lower()
        if any(low.startswith(p) for p in NOISE_PREFIXES):
            continue
        # Los clientes prefijan el binario ("mysqladmin: connect to ...").
        for prefix in ("mysqladmin:", "mariadb-admin:", "pg_isready:", "redis-cli:"):
            if low.startswith(prefix):
                line = line[len(prefix):].strip()
                break
        lines.append(line)

    if not lines:
        return fallback

    # "error: 'Unknown server host ...'" es la linea que realmente explica.
    for line in lines:
        if line.lower().startswith("error:"):
            line = line[len("error:"):].strip().strip("'\"")
            return truncate(line)

    return truncate(lines[0])


def truncate(text, limit=140):
    text = " ".join(text.split())
    return text if len(text) <= limit else text[:limit - 1] + "…"


# --------------------------------------------------------------------------
# metricas: formato y umbrales
# --------------------------------------------------------------------------

def metric(label, value, level=None, ratio=None):
    """Un indicador para la grilla de la tarjeta.

    label  texto corto (la tarjeta tiene ~119px por celda, no escribas parrafos)
    value  ya formateado para mostrar
    level  None | "ok" | "warn" | "crit"  -> color del valor
    ratio  0..1 opcional -> dibuja la barrita de uso debajo del valor
    """
    entry = {"label": label, "value": value}
    if level:
        entry["level"] = level
    if ratio is not None:
        entry["ratio"] = round(max(0.0, min(1.0, ratio)), 3)
    return entry


def level_for(value, warn, crit, invert=False):
    """Nivel segun umbrales. invert=True para metricas donde MENOS es peor
    (hit ratio, por ejemplo)."""
    if value is None:
        return None
    if invert:
        if value <= crit:
            return "crit"
        if value <= warn:
            return "warn"
    else:
        if value >= crit:
            return "crit"
        if value >= warn:
            return "warn"
    return "ok"


def human_bytes(num):
    try:
        num = float(num)
    except (TypeError, ValueError):
        return None
    for unit in ("B", "K", "M", "G", "T"):
        if abs(num) < 1024 or unit == "T":
            return "%.0f%s" % (num, unit) if unit == "B" else "%.1f%s" % (num, unit)
        num /= 1024.0
    return None


def human_duration(secs):
    try:
        secs = int(float(secs))
    except (TypeError, ValueError):
        return None
    if secs < 60:
        return "%ds" % secs
    if secs < 3600:
        return "%dm" % (secs // 60)
    if secs < 86400:
        return "%dh" % (secs // 3600)
    return "%dd" % (secs // 86400)


def to_float(value, default=None):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def conn_metric(used, limit):
    """Conexiones usadas vs maximo -- la metrica que mas temprano avisa que
    una BDD se va a caer, y la unica que la tarjeta dibuja con barra."""
    used = to_float(used)
    limit = to_float(limit)
    if used is None:
        return None
    if not limit:
        return metric("conn", "%d" % used)
    ratio = used / limit
    return metric("conn", "%d/%d" % (used, limit),
                  level_for(ratio, 0.75, 0.9), ratio)


def hit_metric(ratio, label="cache", samples=None):
    """Cache hit ratio: por debajo de ~90% el servidor esta yendo a disco
    todo el tiempo y se nota en latencia mucho antes de que algo se caiga.

    Dos recortes deliberados:
    - Con pocos accesos acumulados el numero no significa nada (una base de
      desarrollo recien levantada da 7% y no tiene ningun problema), asi que
      se muestra sin color en vez de gritar.
    - Nunca llega a "crit": un hit ratio bajo es una señal de performance,
      no un servicio caido, y `crit` ademas baja el status a degraded.
    """
    if ratio is None:
        return None
    if samples is not None and samples < 1000:
        return metric(label, "%.1f%%" % (ratio * 100))
    return metric(label, "%.1f%%" % (ratio * 100),
                  "warn" if ratio < 0.9 else "ok")


def lag_metric(secs):
    if secs is None:
        return None
    return metric("lag", human_duration(secs) or "?",
                  level_for(secs, 10, 60))


# --------------------------------------------------------------------------
# chequeo de puerto (fallback universal)
# --------------------------------------------------------------------------

def tcp_probe(host, port, timeout):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return "up", ""
    except socket.timeout:
        return "down", "timeout de conexion"
    except ConnectionRefusedError:
        return "down", "conexion rechazada"
    except socket.gaierror:
        return "down", "no resuelve el host"
    except OSError as exc:
        return "down", str(exc)


def tcp_fallback(host, port, timeout, missing_client):
    status, note = tcp_probe(host, port, timeout)
    suffix = "solo puerto TCP (falta %s)" % missing_client
    return status, ("%s; %s" % (note, suffix) if note else suffix), []


def wants_metrics(srv):
    return srv.get("metrics", True) is not False


def metrics_required(srv):
    """True solo si el usuario pidio metricas explicitamente -- ahi si vale
    la pena avisar en la tarjeta que no se pudieron juntar. Si es el default
    implicito, se callan: sin credenciales configuradas, el aviso saldria en
    cada tarjeta en cada corrida y seria puro ruido."""
    return srv.get("metrics") is True


# --------------------------------------------------------------------------
# checkers por motor -- devuelven (status, note, metrics)
# --------------------------------------------------------------------------

# Una sola fila con todo: cada psql extra es otro handshake + auth, y esto
# corre cada pocos minutos por cada server de la lista.
PG_SQL = (
    "SELECT (SELECT count(*) FROM pg_stat_activity),"
    " (SELECT setting FROM pg_settings WHERE name='max_connections'),"
    " (SELECT count(*) FROM pg_stat_activity WHERE state='active'),"
    " pg_database_size(current_database()),"
    " EXTRACT(EPOCH FROM (now() - pg_postmaster_start_time()))::bigint,"
    " (SELECT COALESCE(sum(blks_hit)::float8 / NULLIF(sum(blks_hit) + sum(blks_read), 0), 0)"
    "  FROM pg_stat_database),"
    " pg_is_in_recovery(),"
    " CASE WHEN pg_is_in_recovery()"
    "  THEN EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::bigint END,"
    # backend_type='client backend' NO es opcional: sin ese filtro entran los
    # procesos internos (walsender, autovacuum launcher, logical workers), que
    # figuran como 'active' con un query_start del arranque del server. Contra
    # produccion eso daba "query+ 40d" en critico -- 40 dias era el uptime, no
    # una consulta colgada. Requiere PG 10+.
    " (SELECT COALESCE(max(EXTRACT(EPOCH FROM (now() - query_start)))::bigint, 0)"
    "  FROM pg_stat_activity WHERE state='active' AND pid <> pg_backend_pid()"
    "   AND backend_type='client backend'),"
    # Total de accesos a bloques: sin esto no se puede saber si el hit ratio
    # de arriba es representativo o es una base recien levantada.
    " (SELECT COALESCE(sum(blks_hit) + sum(blks_read), 0) FROM pg_stat_database)"
)


def pg_metrics(srv, host, port, timeout):
    if not shutil.which("psql"):
        return [], "psql no instalado"

    cmd = ["psql", "-X", "-w", "-A", "-t", "-q", "-F", "|",
           "-h", host, "-p", str(port),
           "-d", srv.get("database") or "postgres",
           "-c", PG_SQL]
    if srv.get("user"):
        cmd += ["-U", srv["user"]]

    code, out = run(cmd, timeout + 3, {
        "PGPASSWORD": resolve_password(srv),
        "PGCONNECT_TIMEOUT": str(int(timeout)),
    })
    if code != 0 or not out:
        return [], pick_error_line(out, "no se pudieron leer metricas")

    cols = [c.strip() for c in out.splitlines()[0].split("|")]
    if len(cols) < 10:
        return [], "respuesta inesperada de psql"

    conns, max_conns, active, size, uptime, hit, in_recovery, lag, longest = cols[:9]

    out_metrics = []
    for entry in (
        conn_metric(conns, max_conns),
        metric("activas", active) if to_float(active) else None,
        metric("tamaño", human_bytes(size) or "?"),
        hit_metric(to_float(hit), samples=to_float(cols[9]) if len(cols) > 9 else None),
        lag_metric(to_float(lag)) if in_recovery == "t" else None,
        metric("query+", human_duration(longest) or "0s",
               level_for(to_float(longest), 60, 300)) if to_float(longest) else None,
        metric("uptime", human_duration(uptime) or "?"),
        metric("rol", "replica" if in_recovery == "t" else "primary"),
    ):
        if entry:
            out_metrics.append(entry)
    return out_metrics, ""


def check_postgres(srv, host, port, timeout):
    if not shutil.which("pg_isready"):
        return tcp_fallback(host, port, timeout, "pg_isready")

    cmd = ["pg_isready", "-h", host, "-p", str(port), "-t", str(int(timeout))]
    if srv.get("user"):
        cmd += ["-U", srv["user"]]
    if srv.get("database"):
        cmd += ["-d", srv["database"]]

    code, out = run(cmd, timeout + 2, {"PGPASSWORD": resolve_password(srv)})

    if code is None:
        return "down", "timeout (%ss)" % int(timeout), []
    if code == 1:
        # El server contesta pero rechaza conexiones (arrancando, recovery,
        # max_connections). Esta vivo, no sano.
        return "degraded", pick_error_line(out, "rechaza conexiones"), []
    if code == 2:
        return "down", pick_error_line(out), []
    if code != 0:
        return "unknown", pick_error_line(out, "pg_isready fallo (exit %s)" % code), []

    metrics, err = ([], "") if not wants_metrics(srv) else pg_metrics(srv, host, port, timeout)
    return "up", (err if err and metrics_required(srv) else ""), metrics


def parse_kv_lines(out, sep):
    """SHOW GLOBAL STATUS (tab) e INFO de redis (dos puntos) son los dos
    key/value plano -- se parsean igual, con claves en minuscula."""
    data = {}
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, found, value = line.partition(sep)
        if found:
            data[key.strip().lower()] = value.strip()
    return data


def mysql_metrics(srv, host, port, timeout):
    client = shutil.which("mariadb") or shutil.which("mysql")
    if not client:
        return [], "cliente mariadb/mysql no instalado"

    # -N sin encabezados, -B tab-separated: las dos consultas vuelven como
    # pares clave/valor y se parsean juntas en un solo dict.
    query = "SHOW GLOBAL STATUS; SHOW GLOBAL VARIABLES LIKE 'max_connections';"
    if srv.get("replication"):
        query += " SHOW SLAVE STATUS\\G"

    cmd = [client, "-N", "-B", "--connect-timeout=%d" % int(timeout),
           "--host=%s" % host, "--port=%d" % port, "--protocol=TCP", "-e", query]
    if srv.get("user"):
        cmd.append("--user=%s" % srv["user"])
    if srv.get("database"):
        cmd.append(srv["database"])

    code, out = run(cmd, timeout + 3, {"MYSQL_PWD": resolve_password(srv)})
    if code != 0 or not out:
        return [], pick_error_line(out, "no se pudieron leer metricas")

    st = parse_kv_lines(out, "\t")
    # SHOW SLAVE STATUS\G sale como "  Clave: valor", otro separador.
    st.update(parse_kv_lines(out, ":"))

    read_req = to_float(st.get("innodb_buffer_pool_read_requests"), 0)
    reads = to_float(st.get("innodb_buffer_pool_reads"), 0)
    hit = (read_req - reads) / read_req if read_req else None

    lag = to_float(st.get("seconds_behind_master"))
    slow = to_float(st.get("slow_queries"))
    aborted = to_float(st.get("aborted_connects"))

    out_metrics = []
    for entry in (
        conn_metric(st.get("threads_connected"), st.get("max_connections")),
        metric("corriendo", st.get("threads_running")) if st.get("threads_running") else None,
        hit_metric(hit, "buffer", samples=read_req),
        lag_metric(lag),
        # En cero no se muestran (la tarjeta tiene ~8 celdas utiles y
        # "slow q 0" gasta una sin decir nada) y sin nivel cuando existen:
        # son contadores ACUMULADOS desde que arranco el server, no un estado
        # actual. Con "warn" quedaban amarillos para siempre -- 8 slow queries
        # en 11 dias no es un problema, pero el color no se apagaba nunca y
        # terminaba entrenando al ojo a ignorar el amarillo. El dato sirve por
        # su tendencia, que la tarjeta no puede mostrar.
        metric("slow q", "%d" % slow) if slow else None,
        metric("abortadas", "%d" % aborted) if aborted else None,
        metric("uptime", human_duration(st.get("uptime")) or "?"),
    ):
        if entry:
            out_metrics.append(entry)
    return out_metrics, ""


def check_mysql(srv, host, port, timeout):
    # mariadb-admin primero: en Arch, mysqladmin es un alias deprecado que
    # ensucia stderr con su propio warning en cada corrida.
    client = shutil.which("mariadb-admin") or shutil.which("mysqladmin")
    if not client:
        return tcp_fallback(host, port, timeout, "mysqladmin")

    cmd = [
        client, "ping",
        "--host=%s" % host, "--port=%d" % port,
        "--connect-timeout=%d" % int(timeout),
        "--protocol=TCP",
    ]
    if srv.get("user"):
        cmd.append("--user=%s" % srv["user"])

    code, out = run(cmd, timeout + 2, {"MYSQL_PWD": resolve_password(srv)})

    if code is None:
        return "down", "timeout (%ss)" % int(timeout), []
    if code != 0:
        low = out.lower()
        # "Access denied" significa que el server contesto el handshake: esta
        # vivo, lo que falla son las credenciales -> degraded, no down.
        if "access denied" in low or "not allowed to connect" in low:
            return "degraded", "responde pero rechaza credenciales", []
        if "too many connections" in low:
            return "degraded", "too many connections", []
        return "down", pick_error_line(out), []

    metrics, err = ([], "") if not wants_metrics(srv) else mysql_metrics(srv, host, port, timeout)
    return "up", (err if err and metrics_required(srv) else ""), metrics


def check_redis(srv, host, port, timeout):
    if not shutil.which("redis-cli"):
        return tcp_fallback(host, port, timeout, "redis-cli")

    cmd = ["redis-cli", "-h", host, "-p", str(port), "-t", str(int(timeout))]
    if srv.get("user"):
        cmd += ["--user", srv["user"]]
    if srv.get("database") is not None:
        cmd += ["-n", str(srv["database"])]

    # INFO sirve de PING y de fuente de metricas a la vez: si contesta, el
    # server esta vivo. Una sola conexion en vez de dos.
    want = wants_metrics(srv)
    cmd.append("INFO" if want else "PING")

    code, out = run(cmd, timeout + 2, {"REDISCLI_AUTH": resolve_password(srv)})

    if code is None:
        return "down", "timeout (%ss)" % int(timeout), []

    low = out.lower()
    if "noauth" in low or "wrongpass" in low:
        return "degraded", "responde pero rechaza credenciales", []
    # El texto exacto del error, no solo "loading": el INFO trae un campo
    # `loading:0` que hacia matchear a CUALQUIER redis sano como "cargando".
    if "redis is loading" in low:
        return "degraded", "cargando dataset", []
    if not want:
        return ("up", "", []) if "pong" in low else ("down", pick_error_line(out), [])
    if code != 0 or "redis_version" not in low:
        return "down", pick_error_line(out), []

    info = parse_kv_lines(out, ":")

    used = to_float(info.get("used_memory"))
    maxmem = to_float(info.get("maxmemory"))
    hits = to_float(info.get("keyspace_hits"), 0)
    misses = to_float(info.get("keyspace_misses"), 0)
    lookups = hits + misses
    hit = hits / lookups if lookups else None
    evicted = to_float(info.get("evicted_keys"), 0)
    role = info.get("role", "")

    # db0:keys=1234,expires=... -- la cantidad de claves esta adentro del valor.
    keys = 0
    for key, value in info.items():
        if key.startswith("db") and "keys=" in value:
            keys += int(to_float(value.split("keys=")[1].split(",")[0], 0))

    out_metrics = []
    for entry in (
        conn_metric(info.get("connected_clients"), info.get("maxclients")),
        metric("memoria", human_bytes(used) or "?",
               level_for(used / maxmem, 0.75, 0.9) if maxmem else None,
               used / maxmem if maxmem else None),
        hit_metric(hit, samples=lookups),
        metric("claves", "%d" % keys) if keys else None,
        # Evictions > 0 significa que redis ya esta tirando datos para entrar
        # en maxmemory: es la senal de que el cache quedo chico.
        # Acumulado desde el arranque, igual que slow queries: sin nivel.
        metric("evicted", "%d" % evicted) if evicted else None,
        # Un replica con el link caido sigue contestando PING igual: sin esta
        # metrica, la tarjeta te lo mostraria verde mientras sirve datos viejos.
        metric("link", info.get("master_link_status", "?"),
               "ok" if info.get("master_link_status") == "up" else "crit")
        if role == "slave" else None,
        lag_metric(to_float(info.get("master_last_io_seconds_ago"))) if role == "slave" else None,
        metric("rol", "replica" if role == "slave" else "primary"),
        metric("uptime", human_duration(info.get("uptime_in_seconds")) or "?"),
    ):
        if entry:
            out_metrics.append(entry)
    return "up", "", out_metrics


# El ping y las metricas van en el MISMO mongosh: arrancar el shell cuesta
# ~400ms, no tiene sentido pagarlo dos veces. serverStatus() puede fallar por
# permisos sin que eso signifique que el server este mal, por eso va en su
# propio try y el ok se evalua aparte.
MONGO_JS = (
    "var o={};"
    "try{o.ok=db.runCommand({ping:1}).ok}catch(e){o.ok=0};"
    "try{var s=db.serverStatus();"
    "o.conn=s.connections.current;o.avail=s.connections.available;"
    "o.up=s.uptime;o.mem=s.mem?s.mem.resident:null;"
    "o.res=s.globalLock?s.globalLock.currentQueue.total:null;"
    "if(s.repl){o.role=s.repl.isWritablePrimary?'primary':'secondary';"
    "o.set=s.repl.setName}}catch(e){};"
    "try{o.size=db.stats().dataSize}catch(e){};"
    "print(JSON.stringify(o))"
)


def check_mongodb(srv, host, port, timeout):
    if not shutil.which("mongosh"):
        return tcp_fallback(host, port, timeout, "mongosh")

    # serverSelectionTimeoutMS NO existe como flag de mongosh (probado: tira
    # MongoshUnimplementedError y escupe el usage entero) -- va como query
    # param de la URI. Sin esto, mongosh se queda 30s en su default.
    uri = srv.get("uri")
    if not uri:
        uri = "mongodb://%s:%d/%s?serverSelectionTimeoutMS=%d" % (
            host, port, srv.get("database", "admin"), int(timeout * 1000),
        )

    cmd = ["mongosh", uri, "--quiet", "--eval", MONGO_JS]
    if srv.get("user"):
        cmd += ["--username", srv["user"]]
        pwd = resolve_password(srv)
        if pwd:
            cmd += ["--password", pwd]
    if srv.get("auth_database"):
        cmd += ["--authenticationDatabase", srv["auth_database"]]

    code, out = run(cmd, timeout + 5)

    if code is None:
        return "down", "timeout (%ss)" % int(timeout), []

    low = out.lower()
    if "authentication failed" in low or "unauthorized" in low:
        return "degraded", "responde pero rechaza credenciales", []

    data = None
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            try:
                data = json.loads(line)
            except ValueError:
                data = None

    if code != 0 or not data or not data.get("ok"):
        return "down", pick_error_line(out), []

    if not wants_metrics(srv):
        return "up", "", []

    conn = to_float(data.get("conn"))
    avail = to_float(data.get("avail"))
    queued = to_float(data.get("res"))

    out_metrics = []
    for entry in (
        # mongo reporta "disponibles", no el maximo: el total es la suma.
        conn_metric(conn, (conn + avail) if (conn is not None and avail) else None),
        metric("tamaño", human_bytes(data.get("size")) or "?") if data.get("size") else None,
        metric("res mem", human_bytes(to_float(data.get("mem"), 0) * 1024 * 1024) or "?")
        if data.get("mem") else None,
        metric("encolados", "%d" % queued, level_for(queued, 1, 10)) if queued else None,
        metric("rol", data.get("role")) if data.get("role") else None,
        # Solo si serverStatus() respondio: sin permisos de clusterMonitor
        # el ping igual anda, y una tarjeta con un unico "uptime ?" es peor
        # que una sin metricas.
        metric("uptime", human_duration(data.get("up"))) if data.get("up") is not None else None,
    ):
        if entry:
            out_metrics.append(entry)
    return "up", "", out_metrics


def check_docker(srv, host, port, timeout):
    """Estado de un contenedor local (el motor que sea, ya healthcheckeado
    por el propio compose/Dockerfile)."""
    container = srv.get("container") or srv["name"]
    if not shutil.which("docker"):
        return "unknown", "docker no instalado", []

    code, out = run(
        ["docker", "inspect", "-f",
         "{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}"
         "|{{.RestartCount}}|{{.State.StartedAt}}",
         container],
        timeout + 2,
    )
    if code is None:
        return "unknown", "docker inspect colgado", []
    if code != 0:
        return "down", "contenedor no existe", []

    parts = (out.split("|") + ["", "", "", ""])[:4]
    state, health, restarts, started = [p.strip() for p in parts]

    metrics = []
    if wants_metrics(srv):
        started_secs = None
        if started:
            try:
                # Docker devuelve nanosegundos (9 decimales); datetime banca 6.
                iso = started.replace("Z", "+00:00")
                if "." in iso:
                    head, _, tail = iso.partition(".")
                    frac, _, tz = tail.partition("+")
                    iso = "%s.%s+%s" % (head, frac[:6], tz) if tz else "%s.%s" % (head, frac[:6])
                started_secs = (datetime.now(timezone.utc)
                                - datetime.fromisoformat(iso)).total_seconds()
            except ValueError:
                started_secs = None
        if started_secs is not None:
            metrics.append(metric("uptime", human_duration(started_secs) or "?"))
        n = int(to_float(restarts, 0))
        # Un contenedor en crash-loop se ve "running" cada vez que reintenta:
        # el contador de restarts es lo unico que delata el loop.
        if n:
            metrics.append(metric("restarts", "%d" % n, level_for(n, 1, 5)))

    if health:
        if health == "healthy":
            return "up", "", metrics
        if health == "starting":
            return "degraded", "healthcheck arrancando", metrics
        if health == "unhealthy":
            return "down", "healthcheck unhealthy", metrics

    if state == "running":
        return "up", "sin healthcheck", metrics
    if state in ("restarting", "paused"):
        return "degraded", state, metrics
    return "down", state or "estado desconocido", metrics


def check_tcp(srv, host, port, timeout):
    status, note = tcp_probe(host, port, timeout)
    return status, note, []


# --------------------------------------------------------------------------
# webapp / http
# --------------------------------------------------------------------------

# Cuanto del body se lee para los chequeos de contenido. Un endpoint de health
# devuelve unos cientos de bytes; leer entera la pagina de una SPA seria tirar
# megabytes a la basura en cada corrida del timer.
HTTP_BODY_LIMIT = 64 * 1024

HTTP_USER_AGENT = "quickshell-server-check/1"

# Vencimiento del certificado TLS: aviso por defecto. Es una segunda conexion
# por chequeo (~50ms), pero un cert vencido es de las caidas mas tontas y mas
# frecuentes de una webapp. `"cert_warn_days": false` lo apaga.
DEFAULT_CERT_WARN_DAYS = 14


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Con follow_redirects=false urllib deja de seguir el 3xx y lo entrega
    como HTTPError, que es justo lo que queremos evaluar como codigo."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def resolve_secret(srv, prefix):
    """Saca un secreto de donde diga la config, en orden de preferencia:

    <prefix>_env  nombre de una variable de entorno  (recomendado)
    <prefix>_cmd  comando que lo imprime en stdout   (ej. `pass show db/prod`)
    <prefix>      texto plano en el config           (ultimo recurso)
    """
    env_name = srv.get(prefix + "_env")
    if env_name:
        val = os.environ.get(env_name)
        if val is not None:
            return val

    cmd = srv.get(prefix + "_cmd")
    if cmd:
        try:
            # stdin cerrado por el mismo motivo que en run(): los gestores de
            # secretos piden la master password por teclado cuando el vault
            # esta bloqueado. Con el stdin heredado, `bw` sin --nointeraction
            # se cuelga hasta el timeout en vez de fallar al instante.
            out = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=10,
                stdin=subprocess.DEVNULL,
            )
            # Exige salida ademas de exit 0: `bw` bloqueado manda el prompt a
            # stderr, deja stdout vacio y SALE CON 0. Sin este chequeo eso se
            # tomaria como password valida (vacia) y ademas cortaria la cadena
            # de fallback, con el chequeo fallando por "access denied" y ni una
            # pista del motivo real.
            if out.returncode == 0 and out.stdout.strip():
                return out.stdout.strip()
        except subprocess.SubprocessError:
            pass

    return srv.get(prefix)


def http_status_matcher(raw):
    """Normaliza `expect_status` a (predicado, texto para la nota).

    Acepta 200, "200", [200, 204], "2xx", o una mezcla.
    """
    if raw is None:
        return (lambda code: 200 <= code < 400), "200-399"

    items = raw if isinstance(raw, list) else [raw]
    exact, families = set(), set()
    for item in items:
        text = str(item).strip().lower()
        if len(text) == 3 and text.endswith("xx") and text[0].isdigit():
            families.add(int(text[0]))
        else:
            exact.add(int(text))

    def match(code):
        return code in exact or (code // 100) in families

    return match, ", ".join(str(i) for i in items)


def dig(data, path):
    """Camino con puntos ("data.status", "items.0.ok") sobre el JSON parseado."""
    for part in path.split("."):
        if isinstance(data, list):
            try:
                data = data[int(part)]
            except (ValueError, IndexError):
                return None
        elif isinstance(data, dict):
            if part not in data:
                return None
            data = data[part]
        else:
            return None
    return data


def cert_days_left(hostname, port, timeout):
    """Dias hasta que vence el certificado TLS, o None si no se pudo leer.

    Va por conexion aparte a proposito: urllib no expone el peer cert del
    socket que uso para la request.
    """
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((hostname, port), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=hostname) as tls:
                cert = tls.getpeercert()
    except (OSError, ValueError):
        return None

    if not cert or not cert.get("notAfter"):
        return None
    try:
        # notAfter viene siempre en GMT ("Jun  1 12:00:00 2027 GMT").
        expires = datetime.strptime(cert["notAfter"], "%b %d %H:%M:%S %Y %Z")
    except ValueError:
        return None

    delta = expires.replace(tzinfo=timezone.utc) - datetime.now(timezone.utc)
    return delta.days


def http_failure_note(reason):
    """Traduce el motivo de un URLError a algo legible en la tarjeta."""
    if isinstance(reason, ssl.SSLCertVerificationError):
        return truncate("certificado invalido: %s" % (reason.verify_message or reason))
    if isinstance(reason, ssl.SSLError):
        return truncate("error TLS: %s" % reason)
    if isinstance(reason, socket.gaierror):
        return "no resuelve el host"
    if isinstance(reason, ConnectionRefusedError):
        return "conexion rechazada"
    if isinstance(reason, TimeoutError):
        return "timeout de conexion"
    return truncate(str(reason))


def check_http(srv, host, port, timeout):
    """Chequea una webapp / endpoint HTTP.

    A diferencia de los motores de BDD, aca "responde" no alcanza: una app
    puede devolver 200 con la pagina de error adentro, o redirigir al login.
    Por eso ademas del codigo se pueden exigir contenido (`expect_body`) o un
    campo del JSON de health (`json_path` + `json_equals`).
    """
    url = srv.get("url")
    if not url:
        return "unknown", "falta 'url' para el motor 'http'", []

    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return "unknown", "la url debe empezar con http:// o https://", []

    method = str(srv.get("method", "GET")).upper()
    req = urllib.request.Request(url, method=method)
    req.add_header("User-Agent", srv.get("user_agent", HTTP_USER_AGENT))
    for key, value in (srv.get("headers") or {}).items():
        req.add_header(key, str(value))

    token = resolve_secret(srv, "token")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    elif srv.get("user"):
        raw = "%s:%s" % (srv["user"], resolve_password(srv) or "")
        req.add_header("Authorization",
                       "Basic " + base64.b64encode(raw.encode()).decode())

    ctx = ssl._create_unverified_context() if srv.get("insecure") else ssl.create_default_context()
    handlers = [urllib.request.HTTPSHandler(context=ctx)]
    if srv.get("follow_redirects", True) is False:
        handlers.append(NoRedirect())
    opener = urllib.request.build_opener(*handlers)

    try:
        resp = opener.open(req, timeout=timeout)
        try:
            code, body = resp.getcode(), resp.read(HTTP_BODY_LIMIT)
        finally:
            resp.close()
    except urllib.error.HTTPError as exc:
        # Un 3xx/4xx/5xx sigue siendo una respuesta: se evalua igual que un 200.
        code = exc.code
        try:
            body = exc.read(HTTP_BODY_LIMIT)
        except OSError:
            body = b""
        exc.close()
    except urllib.error.URLError as exc:
        return "down", http_failure_note(exc.reason), []
    except (TimeoutError, socket.timeout):
        return "down", "timeout (%ss)" % int(timeout), []
    except (OSError, ValueError) as exc:
        return "down", truncate(str(exc)), []

    text = body.decode("utf-8", "replace")

    # El cuerpo ya parseado se deja a mano para la pasada de metricas custom
    # (json_path), que corre despues en check_server: asi salen de ESTA
    # respuesta en vez de costar una segunda request.
    if custom_specs(srv):
        try:
            srv["_http_payload"] = json.loads(text)
        except ValueError:
            srv["_http_payload"] = None

    matches, expected = http_status_matcher(srv.get("expect_status"))

    metrics = []
    if wants_metrics(srv):
        # El nivel se mide contra lo que la config declaro esperar, no contra
        # 2xx fijo: si pediste expect_status 404, un 404 es el resultado sano y
        # marcarlo "crit" haria que metrics_degrade baje la tarjeta a degraded.
        # crit solo para 5xx (la app esta rota); un 4xx inesperado es warn,
        # porque baja el status a degraded por su cuenta mas abajo y marcarlo
        # crit lo haria por partida doble.
        metrics.append(metric(
            "http", str(code),
            "ok" if matches(code) else ("crit" if code >= 500 else "warn"),
        ))
        # Un body vacio (204, HEAD) no aporta: la celda es una de ~8 utiles.
        if body:
            metrics.append(metric("size", human_bytes(len(body)) or "?"))

    if not matches(code):
        # 5xx: la app contesta pero esta rota -> down.
        # 4xx: esta viva; lo que esta mal es la ruta o la auth del chequeo, que
        # es un problema del monitoreo tanto como del servicio -> degraded.
        return ("down" if code >= 500 else "degraded",
                "HTTP %d (esperaba %s)" % (code, expected), metrics)

    # Con HEAD no hay body que mirar; los chequeos de contenido se saltean en
    # vez de fallar, para que `"method": "HEAD"` no de un falso negativo.
    if method != "HEAD":
        expect_body = srv.get("expect_body")
        if expect_body and str(expect_body) not in text:
            return ("degraded",
                    "HTTP %d pero falta %r en la respuesta"
                    % (code, truncate(str(expect_body), 40)), metrics)

        json_path = srv.get("json_path")
        if json_path:
            try:
                payload = json.loads(text)
            except ValueError:
                return "degraded", "HTTP %d pero la respuesta no es JSON" % code, metrics

            found = dig(payload, json_path)
            if "json_equals" in srv:
                if found != srv["json_equals"]:
                    return ("degraded",
                            "%s = %s (esperaba %s)"
                            % (json_path,
                               json.dumps(found, ensure_ascii=False),
                               json.dumps(srv["json_equals"], ensure_ascii=False)),
                            metrics)
            elif found is None:
                return ("degraded",
                        "HTTP %d pero el JSON no tiene '%s'" % (code, json_path),
                        metrics)

            if wants_metrics(srv) and isinstance(found, (str, int, float, bool)):
                # Unica metrica cuyo label Y valor salen de datos ajenos (el
                # json_path que puso el usuario y lo que conteste la app), asi
                # que se recortan: un {"status": "all systems operational"}
                # desarma la grilla. Los 10/10 salen de medir contra el render:
                # celda util de 115px, label a 5.4px/caracter y valor a 6px
                # (JetBrains Mono, 9px y 10px) -> 54 + 60 = 114. Es el peor
                # caso simultaneo; con un label corto el valor puede pasarse
                # sin romper nada porque el Text hace elide solo.
                metrics.append(metric(
                    truncate(json_path.split(".")[-1], 10),
                    truncate(str(found), 10),
                ))

    if parsed.scheme == "https":
        warn_days = srv.get("cert_warn_days", DEFAULT_CERT_WARN_DAYS)
        if warn_days is not False:
            days = cert_days_left(parsed.hostname, parsed.port or 443, timeout)
            if days is not None:
                if wants_metrics(srv):
                    # crit justo en el umbral que ya baja el status, para que
                    # el color y el estado digan lo mismo; warn bastante antes
                    # (30d) como aviso de "hay que renovarlo". Si bajaste
                    # cert_warn_days a proposito, el crit baja con el.
                    metrics.append(metric(
                        "cert", human_duration(days * 86400) or "%dd" % days,
                        level_for(days, max(30, int(warn_days)), int(warn_days),
                                  invert=True),
                    ))
                if warn_days and days <= int(warn_days):
                    return ("degraded",
                            "el certificado vence en %dd" % days, metrics)

    return "up", "", metrics


# --------------------------------------------------------------------------
# metricas definidas por el usuario
# --------------------------------------------------------------------------

# Techo de tiempo para el SQL del usuario. Las consultas de este script estan
# acotadas por construccion; un count(*) sin indice sobre una tabla grande,
# corriendo cada 5 minutos contra produccion, no lo esta.
CUSTOM_TIMEOUT_MS = 3000

# Mismo criterio que la metrica derivada de json_path: label y valor salen
# los dos de datos que este script no controla, y la celda es de ~119px.
CUSTOM_LABEL_LIMIT = 10
CUSTOM_VALUE_LIMIT = 10

# Marcadores para alinear cada resultado con su spec. Van como sentencia
# propia entre consulta y consulta: si una falla no escribe nada en stdout, y
# el hueco entre dos marcadores dice exactamente cual fue sin arrastrar a las
# demas -- todo con UNA sola conexion. El marcador final acota la zona de
# stdout, porque run() pega stderr despues (ahi caen los ERROR de las que
# fallaron).
CUSTOM_MARK = "##hn%d"
CUSTOM_MARK_END = "##hnEND"


def custom_specs(srv):
    """Entradas validas de `custom_metrics` (las que al menos tienen label)."""
    raw = srv.get("custom_metrics")
    if not isinstance(raw, list):
        return []
    return [s for s in raw if isinstance(s, dict) and s.get("label")]


def scalar_sql(sql):
    """Envuelve la consulta del usuario como subconsulta escalar.

    Si devuelve mas de una fila o mas de una columna, el motor tira un error
    claro ("more than one row returned by a subquery") en vez de que nos
    quedemos con el primer campo de la primera fila y el usuario vea un numero
    que no pidio.
    """
    return "SELECT (%s)" % str(sql or "").strip().rstrip(";").strip()


def split_marked(out, count):
    """Parte una salida marcada en `count` valores, uno por spec.

    None en las posiciones cuya consulta no escribio nada (fallo).
    """
    values = [None] * count
    section = None
    for line in (out or "").splitlines():
        line = line.strip()
        if not line:
            continue
        if line == CUSTOM_MARK_END:
            break
        if line.startswith("##hn"):
            try:
                section = int(line[4:])
            except ValueError:
                section = None
            continue
        if section is not None and 0 <= section < count and values[section] is None:
            values[section] = line
    return values


def seconds_since(iso):
    """Segundos desde un checkedAt del contrato, o None si no se puede leer."""
    try:
        then = datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ")
    except (TypeError, ValueError):
        return None
    return (datetime.now(timezone.utc) - then.replace(tzinfo=timezone.utc)).total_seconds()


def format_custom(spec, num, raw):
    """Numero (o texto) -> lo que se muestra en la celda."""
    fmt = str(spec.get("format", "auto")).lower()
    if num is None or fmt == "text":
        return truncate(str(raw), CUSTOM_VALUE_LIMIT)

    if fmt == "bytes":
        text = human_bytes(num) or "%g" % num
    elif fmt == "duration":
        text = human_duration(num) or "%g" % num
    elif fmt == "percent":
        # 0..1, igual que los hit ratio de mas arriba. Quien tenga 0..100 usa
        # format "number" con suffix "%": preferimos que sea explicito a
        # adivinar por el rango y equivocarnos justo en el 1.
        text = "%.1f%%" % (num * 100)
    else:
        text = "%d" % num if float(num).is_integer() else "%.1f" % num

    return truncate(text + str(spec.get("suffix", "")), CUSTOM_VALUE_LIMIT)


def build_custom_metrics(specs, values, prev_counters, elapsed):
    """Specs + valores crudos -> (metricas del contrato, contadores a guardar).

    Los contadores se devuelven aparte para que la proxima corrida pueda
    calcular tasas sin guardar estado en ningun lado: viajan en el mismo
    servers.json, que ya se relee para el merge.
    """
    metrics, counters = [], {}

    for spec, raw in zip(specs, values):
        label = truncate(str(spec["label"]), CUSTOM_LABEL_LIMIT)
        if raw is None:
            continue

        num = to_float(raw)
        is_rate = bool(spec.get("rate"))

        if is_rate:
            if num is None:
                continue
            # El valor absoluto de un contador desde el arranque ("847392091
            # queries") no dice nada en una tarjeta; lo que interesa es cuanto
            # se movio por segundo.
            counters[label] = num
            before = to_float(prev_counters.get(label))
            if before is None or not elapsed or elapsed <= 0:
                continue  # primera vuelta: todavia no hay contra que restar
            delta = num - before
            if delta < 0:
                # El server se reinicio y el contador volvio a cero. La resta
                # da un negativo sin sentido: se omite esta vuelta, la que
                # viene ya tiene una base valida.
                continue
            num = delta / elapsed
            raw = num

        value = format_custom(spec, num, raw)

        level = None
        warn, crit = to_float(spec.get("warn")), to_float(spec.get("crit"))
        if warn is not None or crit is not None:
            level = level_for(num, warn if warn is not None else crit,
                              crit if crit is not None else warn,
                              invert=bool(spec.get("invert")))

        ratio = None
        top = to_float(spec.get("max"))
        if top and num is not None:
            ratio = num / top

        entry = metric(label, value, level, ratio)
        # Por default una metrica custom NO baja el status: "pedidos > 500" es
        # una metrica de negocio, y un dia de ventas bueno no es una base de
        # datos degradada. Si el indicador de salud se pone amarillo por eso,
        # deja de significar salud. `"degrade": true` para las que si midan
        # salud (locks sin otorgar, cola de trabajos encolada).
        if not spec.get("degrade"):
            entry["_informative"] = True
        metrics.append(entry)

    return metrics, counters


def pg_custom_values(srv, host, port, timeout, specs):
    if not shutil.which("psql"):
        return None, "psql no instalado"

    cmd = ["psql", "-X", "-w", "-A", "-t", "-q",
           "-h", host, "-p", str(port),
           "-d", srv.get("database") or "postgres",
           # El corralito va ANTES del SQL del usuario y en la misma sesion:
           # esto corre con credenciales reales contra su base y la consulta
           # no la escribimos nosotros. Barato de poner ahora, imposible de
           # agregar despues de un accidente.
           "-c", "SET default_transaction_read_only=on",
           "-c", "SET statement_timeout='%dms'" % CUSTOM_TIMEOUT_MS]
    for i, spec in enumerate(specs):
        cmd += ["-c", "\\echo " + CUSTOM_MARK % i,
                "-c", scalar_sql(spec.get("sql"))]
    cmd += ["-c", "\\echo " + CUSTOM_MARK_END]
    if srv.get("user"):
        cmd += ["-U", srv["user"]]

    code, out = run(cmd, timeout + CUSTOM_TIMEOUT_MS / 1000.0 + 3, {
        "PGPASSWORD": resolve_password(srv),
        "PGCONNECT_TIMEOUT": str(int(timeout)),
    })
    if code is None:
        return None, "timeout leyendo metricas custom"
    if not out:
        return None, "sin respuesta de psql"
    return split_marked(out, len(specs)), ""


def mysql_custom_values(srv, host, port, timeout, specs):
    client = shutil.which("mariadb") or shutil.which("mysql")
    if not client:
        return None, "cliente mariadb/mysql no instalado"

    # Las dos formas del techo de tiempo: max_execution_time es MySQL 5.7+ y
    # max_statement_time es MariaDB. La que no corresponda falla sola y --force
    # sigue de largo, asi que poner las dos cubre los dos motores sin tener que
    # detectar la version.
    stmts = ["SET SESSION max_execution_time=%d" % CUSTOM_TIMEOUT_MS,
             "SET SESSION max_statement_time=%.1f" % (CUSTOM_TIMEOUT_MS / 1000.0),
             "SET SESSION TRANSACTION READ ONLY"]
    for i, spec in enumerate(specs):
        stmts.append("SELECT '%s'" % (CUSTOM_MARK % i))
        stmts.append(scalar_sql(spec.get("sql")))
    stmts.append("SELECT '%s'" % CUSTOM_MARK_END)

    cmd = [client, "-N", "-B", "--force",
           "--connect-timeout=%d" % int(timeout),
           "--host=%s" % host, "--port=%d" % port, "--protocol=TCP",
           "-e", "; ".join(stmts)]
    if srv.get("user"):
        cmd.append("--user=%s" % srv["user"])
    if srv.get("database"):
        cmd.append(srv["database"])

    code, out = run(cmd, timeout + CUSTOM_TIMEOUT_MS / 1000.0 + 3,
                    {"MYSQL_PWD": resolve_password(srv)})
    if code is None:
        return None, "timeout leyendo metricas custom"
    if not out:
        return None, "sin respuesta del cliente mysql"
    return split_marked(out, len(specs)), ""


def redis_custom_values(srv, host, port, timeout, specs):
    if not shutil.which("redis-cli"):
        return None, "redis-cli no instalado"

    # Unico motor con una invocacion por metrica: redis-cli toma un comando
    # por corrida. Una conexion a redis cuesta ~1ms, muy lejos del handshake +
    # auth de una BDD, asi que no vale la pena complicar el batching.
    values = []
    for spec in specs:
        command = spec.get("command")
        if not command:
            values.append(None)
            continue
        cmd = ["redis-cli", "-h", host, "-p", str(port), "-t", str(int(timeout))]
        if srv.get("user"):
            cmd += ["--user", srv["user"]]
        if srv.get("database") is not None:
            cmd += ["-n", str(srv["database"])]
        try:
            cmd += shlex.split(str(command))
        except ValueError:
            values.append(None)
            continue
        code, out = run(cmd, timeout + 2, {"REDISCLI_AUTH": resolve_password(srv)})
        low = (out or "").lower()
        if code != 0 or low.startswith("err") or low.startswith("wrongtype"):
            values.append(None)
        else:
            values.append(out.strip().strip('"'))
    return values, ""


def mongo_custom_values(srv, host, port, timeout, specs):
    if not shutil.which("mongosh"):
        return None, "mongosh no instalado"

    # Cada expresion envuelta en su propio try: una que falle devuelve null y
    # las demas siguen, mismo aislamiento que dan los marcadores en SQL.
    parts = []
    for spec in specs:
        expr = str(spec.get("eval") or "null")
        parts.append("(()=>{try{return String(%s)}catch(e){return null}})()" % expr)
    script = "print(JSON.stringify([%s]))" % ",".join(parts)

    uri = srv.get("uri") or "mongodb://%s:%d/%s?serverSelectionTimeoutMS=%d" % (
        host, port, srv.get("database", "admin"), int(timeout * 1000))
    cmd = ["mongosh", uri, "--quiet", "--eval", script]
    if srv.get("user"):
        cmd += ["--username", srv["user"]]
        pwd = resolve_password(srv)
        if pwd:
            cmd += ["--password", pwd]
    if srv.get("auth_database"):
        cmd += ["--authenticationDatabase", srv["auth_database"]]

    code, out = run(cmd, timeout + CUSTOM_TIMEOUT_MS / 1000.0 + 5)
    if code is None:
        return None, "timeout leyendo metricas custom"
    for line in (out or "").splitlines():
        line = line.strip()
        if line.startswith("["):
            try:
                data = json.loads(line)
            except ValueError:
                break
            return [None if v is None else str(v) for v in data][:len(specs)], ""
    return None, pick_error_line(out or "", "no se pudieron leer metricas custom")


def http_custom_values(srv, host, port, timeout, specs):
    """Metricas custom de una webapp: salen del cuerpo que ya trajo
    check_http, asi que no cuestan una request extra."""
    payload = srv.pop("_http_payload", None)
    if payload is None:
        return None, "la respuesta no es JSON"

    values = []
    for spec in specs:
        path = spec.get("json_path")
        found = dig(payload, path) if path else None
        values.append(None if found is None else str(found))
    return values, ""


CUSTOM_COLLECTORS = {
    "http": http_custom_values,
    "https": http_custom_values,
    "webapp": http_custom_values,
    "postgres": pg_custom_values,
    "postgresql": pg_custom_values,
    "mysql": mysql_custom_values,
    "mariadb": mysql_custom_values,
    "redis": redis_custom_values,
    "mongodb": mongo_custom_values,
    "mongo": mongo_custom_values,
}


def custom_metrics_pass(srv, engine, host, port, timeout, previous):
    """Pasada aparte para las metricas del usuario.

    Aparte y no dentro de las consultas de cada motor a proposito: si el SQL
    del usuario entrara en la consulta de una sola fila de pg_metrics, un typo
    suyo no romperia su metrica sino TODAS las de ese servidor, porque el
    parseo por columnas se desalinea entero. Aca su consulta falla sola.
    """
    specs = custom_specs(srv)
    if not specs:
        return [], {}, ""

    collector = CUSTOM_COLLECTORS.get(engine)
    if collector is None:
        return [], {}, "custom_metrics no soportado en '%s'" % engine

    values, note = collector(srv, host, port, timeout, specs)
    if values is None:
        return [], {}, note

    prev_counters = (previous or {}).get("_counters") or {}
    elapsed = seconds_since((previous or {}).get("checkedAt"))
    metrics, counters = build_custom_metrics(specs, values, prev_counters, elapsed)

    fallidas = [s["label"] for s, v in zip(specs, values) if v is None]
    if fallidas and metrics_required(srv):
        note = "custom sin datos: " + truncate(", ".join(fallidas), 60)
    return metrics, counters, note


CHECKERS = {
    "postgres": check_postgres,
    "postgresql": check_postgres,
    "mysql": check_mysql,
    "mariadb": check_mysql,
    "redis": check_redis,
    "mongodb": check_mongodb,
    "mongo": check_mongodb,
    "docker": check_docker,
    "http": check_http,
    "https": check_http,
    "webapp": check_http,
    "tcp": check_tcp,
}


# --------------------------------------------------------------------------
# orquestacion
# --------------------------------------------------------------------------

def check_server(srv, previous=None):
    """Chequea una entrada de config y devuelve el dict del contrato.

    `previous` es la entrada de la corrida anterior, si la hay: de ahi
    salen los contadores con los que se calculan las tasas.
    """
    name = srv.get("name") or srv.get("host") or "sin-nombre"
    engine = str(srv.get("engine", "tcp")).lower()
    host = srv.get("host", "127.0.0.1")
    port = int(srv.get("port") or DEFAULT_PORTS.get(engine, 0))
    timeout = float(srv.get("timeout", DEFAULT_TIMEOUT))

    checker = CHECKERS.get(engine)

    started = time.monotonic()
    metrics = []
    if checker is None:
        status, note = "unknown", "motor '%s' no soportado" % engine
    elif port == 0 and engine not in PORTLESS_ENGINES:
        status, note = "unknown", "falta 'port' para el motor '%s'" % engine
    else:
        try:
            status, note, metrics = checker(srv, host, port, timeout)
        except Exception as exc:  # un checker roto no debe tumbar el resto
            status, note, metrics = "unknown", "error del checker: %s" % exc, []
    latency = int((time.monotonic() - started) * 1000)

    # Metricas del usuario: solo si el server contesto (si esta caido no hay a
    # quien consultarle) y solo si no se pidio `"metrics": false`.
    counters = {}
    if status in ("up", "degraded") and wants_metrics(srv):
        try:
            extra, counters, cnote = custom_metrics_pass(
                srv, engine, host, port, timeout, previous)
            metrics = list(metrics) + extra
            note = note or cnote
        except Exception as exc:
            note = note or ("error en custom_metrics: %s" % exc)

    # Responde, pero lento: se marca degraded para que la tarjeta avise
    # antes de que el servicio se caiga del todo.
    slow_ms = srv.get("slow_ms")
    if status == "up" and slow_ms is not None and latency > int(slow_ms):
        status = "degraded"
        note = "lento (%dms > %dms)" % (latency, int(slow_ms))

    # Una metrica en critico (conexiones al tope, replica desenganchada) es
    # un problema real aunque el server siga contestando: si no bajara el
    # status, la tarjeta quedaria verde y habria que leerle la letra chica.
    if status == "up" and srv.get("metrics_degrade", True):
        crit = [m["label"] for m in metrics
                if m.get("level") == "crit" and not m.get("_informative")]
        if crit:
            status = "degraded"
            note = note or ("en critico: " + ", ".join(crit))

    entry = {
        "name": name,
        "status": status,
        "latencyMs": latency,
        "checkedAt": now_iso(),
        "source": SOURCE_TAG,
    }

    if engine != "tcp":
        entry["engine"] = engine

    url = srv.get("url")
    if url is None and engine not in PORTLESS_ENGINES and port:
        url = "%s:%d" % (host, port)
    if url:
        entry["url"] = url

    # La nota de la config es contexto fijo ("replica de lectura"); la del
    # chequeo es el motivo de la falla y manda cuando algo esta mal.
    note = note or srv.get("note", "")
    if note:
        entry["note"] = note

    for m in metrics:
        m.pop("_informative", None)
    if metrics:
        entry["metrics"] = metrics
    # Los contadores viajan en el servers.json para que la proxima corrida
    # pueda restar y sacar la tasa. El QML ignora las claves que no conoce.
    if counters:
        entry["_counters"] = counters

    return entry


class ConfigError(Exception):
    """Config ilegible o mal formado.

    Es una excepcion y no un sys.exit() porque el modo `--interval` relee el
    config en cada vuelta: si lo estas editando justo cuando toca chequear, el
    daemon tiene que quejarse y seguir con la lista anterior, no morirse.
    """


def load_config(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        raise ConfigError(
            "no existe el config: %s\n"
            "copia db-servers.example.json ahi y edita tu lista de servidores."
            % path
        )
    except (json.JSONDecodeError, OSError) as exc:
        raise ConfigError("config invalido (%s): %s" % (path, exc))

    servers = data.get("servers") if isinstance(data, dict) else data
    if not isinstance(servers, list):
        raise ConfigError(
            "el config debe ser un array, o un objeto con la clave 'servers'")

    return [s for s in servers if isinstance(s, dict) and s.get("enabled", True)]


def select_servers(args):
    """Config -> lista final de servidores a chequear, ya filtrada."""
    servers = load_config(args.config)

    if args.only:
        wanted = set(args.only)
        servers = [s for s in servers if s.get("name") in wanted]
        if not servers:
            raise ConfigError("ninguna entrada del config coincide con --only")
    if not servers:
        raise ConfigError("el config no tiene servidores habilitados")
    if args.no_metrics:
        servers = [dict(s, metrics=False) for s in servers]

    return servers


def check_all(servers, jobs, previous=None):
    # En paralelo para que un server colgado no sume su timeout al total.
    prev = {e["name"]: e for e in (previous or []) if isinstance(e, dict) and e.get("name")}
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        return list(pool.map(lambda s: check_server(s, prev.get(s.get("name"))), servers))


def parse_interval(raw):
    """Acepta segundos pelados o con sufijo: 90, "90s", "5m", "1h"."""
    text = str(raw).strip().lower()
    # Mirar el sufijo, no el factor: "s" vale 1 y comparar contra 1 hacia que
    # "30s" no se recortara nunca y terminara en float("30s").
    suffixes = {"s": 1, "m": 60, "h": 3600}
    factor = 1
    if text and text[-1] in suffixes:
        factor = suffixes[text[-1]]
        text = text[:-1]
    try:
        secs = float(text) * factor
    except ValueError:
        raise argparse.ArgumentTypeError(
            "intervalo invalido: %r (usa 30, 30s, 5m, 1h)" % raw)
    if secs < 5:
        raise argparse.ArgumentTypeError("el intervalo minimo es 5s")
    return secs


def load_existing(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return []
    return data if isinstance(data, list) else []


def write_atomic(path, payload):
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)

    # El temporal va en el MISMO directorio que el destino a proposito: un
    # os.replace() entre filesystems distintos (ej. /tmp en tmpfs) no es
    # atomico, y ahi ServersTab.qml puede leer el archivo a medio escribir.
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".servers-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def run_once(args, servers):
    """Una pasada completa: chequea, y escribe (o imprime)."""
    # Se lee ANTES de chequear: de la corrida anterior salen los contadores
    # con los que se calculan las tasas (y despues se reusa para el merge).
    existing = load_existing(args.out)
    entries = check_all(servers, args.jobs, existing)

    if args.dry:
        json.dump(entries, sys.stdout, indent=2, ensure_ascii=False)
        sys.stdout.write("\n")
        # Con --interval y la salida redirigida a un archivo, stdout queda
        # con buffer de bloque y no se ve nada hasta que se llena.
        sys.stdout.flush()
        return entries

    payload = entries
    if not args.no_merge:
        mine = {e["name"] for e in entries}
        foreign = [
            e for e in existing
            if isinstance(e, dict)
            and e.get("source") != SOURCE_TAG
            and e.get("name") not in mine
        ]
        payload = foreign + entries

    write_atomic(args.out, payload)
    return entries


def summarize(entries, stamped=False):
    """Resumen a stderr: no molesta si lo corre un timer, y sirve a mano."""
    bad = [e for e in entries if e["status"] != "up"]
    stamp = time.strftime("[%H:%M:%S] ") if stamped else ""
    print("%s%d servidores chequeados, %d con problemas%s"
          % (stamp, len(entries), len(bad),
             (": " + ", ".join("%s (%s)" % (e["name"], e["status"]) for e in bad))
             if bad else ""),
          file=sys.stderr)


def run_forever(args, interval):
    """Modo daemon: chequea cada `interval` segundos hasta que lo maten.

    Tres cosas lo hacen sobrevivir a una noche entera sin niñera:
    relee el config en cada vuelta (editarlo no requiere reiniciar), una
    vuelta que revienta no mata el proceso, y SIGTERM/SIGINT cortan limpio
    para que `systemctl stop` no tenga que mandar SIGKILL.
    """
    stopping = []

    def handler(signum, _frame):
        stopping.append(signum)
        print("señal %d recibida, cerrando" % signum, file=sys.stderr)

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, handler)

    servers = None
    while not stopping:
        started = time.monotonic()

        try:
            servers = select_servers(args)
        except ConfigError as exc:
            if servers is None:
                # Nunca hubo una lista valida: no hay con que seguir, y fallar
                # ya deja el error visible en `systemctl status`.
                print(exc, file=sys.stderr)
                return 1
            print("[%s] config ilegible, sigo con la lista anterior: %s"
                  % (time.strftime("%H:%M:%S"), exc), file=sys.stderr)

        try:
            summarize(run_once(args, servers), stamped=True)
        except Exception as exc:
            # Un disco lleno, un DNS que se cayo, un cliente que segfaultea:
            # nada de eso justifica perder el daemon y dejar de chequear.
            print("[%s] la corrida fallo: %s"
                  % (time.strftime("%H:%M:%S"), exc), file=sys.stderr)

        # Descontar lo que tardo la corrida mantiene el periodo parejo en vez
        # de correrse un poco en cada vuelta.
        deadline = started + interval
        while not stopping:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            # De a un segundo para que una señal se note enseguida y no
            # tengamos que esperar el intervalo entero para salir.
            time.sleep(min(1.0, remaining))

    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Chequea servidores de BDD y actualiza servers.json "
                    "para el dashboard de Quickshell.",
    )
    parser.add_argument("-c", "--config", default=DEFAULT_CONFIG,
                        help="config con la lista de servidores (default: %(default)s)")
    parser.add_argument("-o", "--out", default=DEFAULT_OUT,
                        help="JSON que lee ServersTab.qml (default: %(default)s)")
    parser.add_argument("--only", metavar="NOMBRE", action="append",
                        help="chequear solo estas entradas (repetible)")
    parser.add_argument("--print", dest="dry", action="store_true",
                        help="imprimir el resultado por stdout sin escribir nada")
    parser.add_argument("--no-metrics", action="store_true",
                        help="solo up/down, sin consultar metricas a los motores")
    parser.add_argument("--no-merge", action="store_true",
                        help="pisar el archivo entero en vez de conservar las "
                             "entradas de otros checkers")
    parser.add_argument("-j", "--jobs", type=int, default=8,
                        help="chequeos en paralelo (default: %(default)s)")
    parser.add_argument("-i", "--interval", type=parse_interval, metavar="TIEMPO",
                        help="correr indefinidamente, chequeando cada TIEMPO "
                             "(30, 30s, 5m, 1h). Sin esto hace una sola pasada "
                             "y termina, que es lo que quiere un systemd timer")
    args = parser.parse_args()

    if args.interval:
        return run_forever(args, args.interval)

    try:
        servers = select_servers(args)
    except ConfigError as exc:
        sys.exit(str(exc))

    summarize(run_once(args, servers))

    # Exit 0 aunque haya servidores caidos: eso es el resultado esperado del
    # chequeo, no una falla del script. Si devolviera != 0, systemd marcaria
    # la unit como failed cada vez que un server se cae, que es justo el caso
    # para el que existe esto. Los exit 1 son solo errores de config/uso.
    return 0


if __name__ == "__main__":
    sys.exit(main())
