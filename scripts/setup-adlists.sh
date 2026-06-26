#!/bin/bash
# ============================================================
#  Pi Home Server — importa liste e regole in Pi-hole dai file della repo
#    pihole/adlists.txt          -> adlist (liste di blocco)
#    pihole/allowlist.txt        -> domainlist type 0 (allow esatti)
#    pihole/regex-blocklist.txt  -> domainlist type 3 (regex deny)
#  Idempotente: salta ciò che è già presente.
#  Pi-hole v6: usa pihole-FTL sqlite3 (il binario sqlite3 non è incluso).
# ============================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAVITY="/etc/pihole/gravity.db"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }

# Esegue una query nel DB di Pi-hole (FTL ha sqlite3 integrato in v6)
db() { docker exec pihole pihole-FTL sqlite3 "$GRAVITY" "$1"; }

adlists_added=0
domains_added=0

info "Attesa che Pi-hole sia pronto..."
for _ in $(seq 1 30); do
    docker exec pihole pihole status &>/dev/null && break
    sleep 2
done

# ── Liste di blocco (tabella adlist) ─────────────────────────
import_adlists() {
    local file="$SCRIPT_DIR/pihole/adlists.txt"
    [[ -f "$file" ]] || { warn "adlists.txt non trovato, skip."; return; }
    info "Importazione liste di blocco..."
    local line safe
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        safe="${line//"'"/"''"}"
        if [[ "$(db "SELECT COUNT(*) FROM adlist WHERE address='$safe';")" == "0" ]]; then
            db "INSERT INTO adlist (address, enabled) VALUES ('$safe', 1);"
            info "  + lista: $line"
            adlists_added=$((adlists_added + 1))
        fi
    done < "$file"
}

# ── Domini allow/regex (tabella domainlist) ──────────────────
# $1 = nome file, $2 = type (0 allow esatto / 3 regex deny), $3 = etichetta
import_domainlist() {
    local file="$SCRIPT_DIR/pihole/$1" type="$2" label="$3"
    [[ -f "$file" ]] || { warn "$1 non trovato, skip."; return; }
    info "Importazione $label..."
    local line safe
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        safe="${line//"'"/"''"}"
        if [[ "$(db "SELECT COUNT(*) FROM domainlist WHERE type=$type AND domain='$safe';")" == "0" ]]; then
            db "INSERT INTO domainlist (type, domain, enabled) VALUES ($type, '$safe', 1);"
            info "  + $label: $line"
            domains_added=$((domains_added + 1))
        fi
    done < "$file"
}

import_adlists
import_domainlist allowlist.txt 0 "allow esatto"
import_domainlist regex-blocklist.txt 3 "regex deny"

# ── Applica le modifiche ─────────────────────────────────────
if [[ $adlists_added -gt 0 ]]; then
    info "$adlists_added nuove liste → aggiorno gravity..."
    docker exec pihole pihole -g
elif [[ $domains_added -gt 0 ]]; then
    info "Ricarico le liste di dominio..."
    docker exec pihole pihole reloadlists
fi

info "Fatto: $adlists_added liste, $domains_added tra allow/regex aggiunti."
