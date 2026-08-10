#!/usr/bin/env bash
# Plantilla, NO wired a autostart/cron -- copiala, cambiale el nombre
# (sacale el ".example"), poné tu lista real de servidores, y correla vos
# desde donde te convenga: un cron/systemd --user timer en esta maquina,
# o en la maquina de laburo si el JSON despues lo sincronizas para aca
# (scp/syncthing/lo que uses).
#
# Contrato que lee modules/dashboard/ServersTab.qml:
#   ~/.local/state/quickshell/servers.json
#   [ { "name": str (obligatorio),
#       "status": "up"|"down"|"degraded" (cualquier otra cosa -> "unknown"),
#       "url": str (opcional, se muestra en la tarjeta),
#       "latencyMs": number (opcional),
#       "checkedAt": ISO8601 (opcional, se muestra como "hace Xm"),
#       "note": str (opcional, motivo si esta down/degraded) }, ... ]
#
# Se escribe con un mv atomico (tmp -> final) para que ServersTab.qml
# (que mira el archivo con FileView.watchChanges) nunca lo lea a la mitad.

set -euo pipefail

OUT="$HOME/.local/state/quickshell/servers.json"
TMP="$(mktemp)"
mkdir -p "$(dirname "$OUT")"

# Editá esto con tus servidores reales: nombre | url a pegarle con curl.
SERVERS=(
    "prod-api|https://api.example.com/health"
    "staging-db|https://staging.example.com/health"
)

entries=()
for entry in "${SERVERS[@]}"; do
    name="${entry%%|*}"
    url="${entry#*|}"

    start_ms=$(date +%s%3N)
    if code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null); then
        end_ms=$(date +%s%3N)
        latency=$((end_ms - start_ms))
        if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
            status="up"
            note=""
        else
            status="degraded"
            note="HTTP $code"
        fi
    else
        status="down"
        note="sin respuesta"
        latency=0
    fi

    checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    entries+=("$(python3 -c '
import json, sys
name, url, status, latency, note, checked_at = sys.argv[1:7]
print(json.dumps({
    "name": name, "url": url, "status": status,
    "latencyMs": int(latency), "note": note, "checkedAt": checked_at,
}))
' "$name" "$url" "$status" "$latency" "$note" "$checked_at")")
done

python3 -c '
import json, sys
print(json.dumps([json.loads(e) for e in sys.argv[1:]], indent=2))
' "${entries[@]}" > "$TMP"

mv "$TMP" "$OUT"
