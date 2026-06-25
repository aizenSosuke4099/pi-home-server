#!/bin/bash
# ============================================================
#  Pi Home Server — backup dei dati persistenti
#  Salva i bind-mount (config, certificati, chiavi VPN, DB) + .env in un
#  archivio tar.gz datato, con rotazione automatica.
#
#  Config in .env:
#    BACKUP_DEST -> cartella di destinazione (default: <repo>/backups)
#    BACKUP_KEEP -> quanti backup tenere (default: 7)
#
#  Uso:  sudo bash scripts/backup.sh
#  Log:  /var/log/pi-home-backup.log
# ============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/var/log/pi-home-backup.log"
ENV_FILE="$REPO_DIR/.env"

[[ $EUID -ne 0 ]] && { echo "Esegui come root: sudo bash scripts/backup.sh"; exit 1; }

get_env() {
    [[ -f "$ENV_FILE" ]] || return 0
    sed -nE "s/^[[:space:]]*$1=[[:space:]]*//p" "$ENV_FILE" | tail -1 \
        | sed -E 's/[[:space:]]+#.*$//; s/^"//; s/"$//; s/[[:space:]]*$//'
}

exec > >(tee -a "$LOG") 2>&1
echo ""
echo "── Backup: $(date '+%Y-%m-%d %H:%M:%S') ──────────────────────────"

BACKUP_DEST="$(get_env BACKUP_DEST)"; BACKUP_DEST="${BACKUP_DEST:-$REPO_DIR/backups}"
BACKUP_KEEP="$(get_env BACKUP_KEEP)"; BACKUP_KEEP="${BACKUP_KEEP:-7}"
mkdir -p "$BACKUP_DEST"

# Avviso se la destinazione è sullo stesso disco del Pi (non protegge da guasto SD)
if [[ "$(stat -c %d "$BACKUP_DEST" 2>/dev/null)" == "$(stat -c %d "$REPO_DIR" 2>/dev/null)" ]]; then
    echo "  [WARN] BACKUP_DEST è sullo stesso disco del Pi: NON protegge da un guasto della SD."
    echo "         Imposta BACKUP_DEST nel .env su una USB o un NAS."
fi

cd "$REPO_DIR" || { echo "  [FAIL] cartella repo non raggiungibile: $REPO_DIR"; exit 1; }
ITEMS=( .env
        pihole/etc-pihole pihole/dnsmasq pihole/custom-hosts.txt
        npm/data npm/letsencrypt
        uptime-kuma/data
        wireguard/config
        homepage/config )

existing=()
for i in "${ITEMS[@]}"; do [[ -e "$i" ]] && existing+=("$i"); done
if [[ ${#existing[@]} -eq 0 ]]; then
    echo "  [FAIL] Nessun dato da salvare (sei nella cartella giusta?)."
    exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DEST/pi-home-backup-$TS.tar.gz"
echo "  Creo l'archivio: $ARCHIVE"

if tar -czf "$ARCHIVE" "${existing[@]}" && tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
    echo "  [OK] Backup creato ($(du -h "$ARCHIVE" | cut -f1))"
else
    echo "  [FAIL] Backup fallito o archivio corrotto!"
    bash "$REPO_DIR/scripts/notify.sh" "⚠️ Pi Home: BACKUP fallito" \
        "Il backup del $(date '+%d/%m %H:%M') non è riuscito. Controlla $LOG" high
    exit 1
fi

# Rotazione: elimina i backup oltre gli ultimi BACKUP_KEEP
mapfile -t old < <(ls -1t "$BACKUP_DEST"/pi-home-backup-*.tar.gz 2>/dev/null | tail -n +"$((BACKUP_KEEP + 1))")
if [[ ${#old[@]} -gt 0 ]]; then
    rm -f "${old[@]}"
    echo "  Rimossi ${#old[@]} backup vecchi (tenuti gli ultimi $BACKUP_KEEP)."
fi

echo "  [FINE] Backup completato."
exit 0
