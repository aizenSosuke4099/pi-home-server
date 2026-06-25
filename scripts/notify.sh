#!/bin/bash
# ============================================================
#  Pi Home Server — notifica via ntfy (https://ntfy.sh)
#  Configurazione in .env:
#    NTFY_TOPIC -> topic (obbligatorio per attivare le notifiche)
#    NTFY_URL   -> server ntfy (default https://ntfy.sh)
#  No-op silenzioso se NTFY_TOPIC non è impostato. Non fallisce mai.
#  Uso:  bash scripts/notify.sh "Titolo" "Messaggio" [priorità]
# ============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

get_env() {
    [[ -f "$ENV_FILE" ]] || return 0
    sed -nE "s/^[[:space:]]*$1=[[:space:]]*//p" "$ENV_FILE" | tail -1 \
        | sed -E 's/[[:space:]]+#.*$//; s/^"//; s/"$//; s/[[:space:]]*$//'
}

TITLE="${1:-Pi Home Server}"
MSG="${2:-}"
PRIO="${3:-default}"
TOPIC="$(get_env NTFY_TOPIC)"
URL="$(get_env NTFY_URL)"; URL="${URL:-https://ntfy.sh}"

[[ -z "$TOPIC" ]] && exit 0   # notifiche non configurate → esci in silenzio

curl -fsS -m 10 \
    -H "Title: $TITLE" \
    -H "Priority: $PRIO" \
    -d "$MSG" \
    "${URL%/}/$TOPIC" >/dev/null 2>&1 || true
exit 0
