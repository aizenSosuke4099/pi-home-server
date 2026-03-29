#!/bin/bash
# Importa le liste di blocco in Pi-hole dalla lista predefinita
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADLISTS_FILE="$SCRIPT_DIR/pihole/adlists.txt"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }

if [[ ! -f "$ADLISTS_FILE" ]]; then
    warn "File adlists.txt non trovato, skip."
    exit 0
fi

info "Attesa che Pi-hole sia pronto..."
for i in $(seq 1 30); do
    if docker exec pihole pihole status &>/dev/null; then
        break
    fi
    sleep 2
done

info "Importazione liste di blocco..."
count=0
while IFS= read -r line; do
    # Ignora commenti e righe vuote
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Controlla se la lista è già presente
    if docker exec pihole sqlite3 /etc/pihole/gravity.db \
        "SELECT COUNT(*) FROM adlist WHERE address='$line';" | grep -q "^0$"; then
        docker exec pihole sqlite3 /etc/pihole/gravity.db \
            "INSERT INTO adlist (address, enabled) VALUES ('$line', 1);"
        ((count++))
        info "  + $line"
    fi
done < "$ADLISTS_FILE"

if [[ $count -gt 0 ]]; then
    info "$count nuove liste aggiunte. Aggiornamento gravity..."
    docker exec pihole pihole -g
    info "Gravity aggiornato con successo."
else
    info "Tutte le liste sono già presenti."
fi
