#!/bin/bash
# ============================================================
#  Pi Home Server — aggiornamento completo
#  Aggiorna: sistema operativo del Pi + engine Docker + container dello stack.
#
#  Uso manuale:                 sudo bash scripts/update.sh
#  Uso schedulato (riavvia se
#  kernel/firmware lo richiede): sudo bash scripts/update.sh --reboot
#
#  Log persistente in: /var/log/pi-home-update.log
# ============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/var/log/pi-home-update.log"
REBOOT_IF_REQUIRED=0
[[ "${1:-}" == "--reboot" ]] && REBOOT_IF_REQUIRED=1

# ── Root richiesto (serve per apt) ───────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Esegui come root: sudo bash scripts/update.sh"
    exit 1
fi

# ── Tutto l'output va anche su file di log ───────────────────
exec > >(tee -a "$LOG") 2>&1
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Pi Home Server — update: $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════════════"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a          # non chiedere quali servizi riavviare

# ── 1. Sistema operativo + engine Docker ─────────────────────
# Il repo apt di Docker è già configurato (install.sh), quindi full-upgrade
# aggiorna sia i pacchetti del Pi OS sia docker-ce/containerd.
echo "[1/4] Aggiornamento sistema operativo e Docker engine..."
apt-get update -qq
apt-get -y \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confdef" \
    full-upgrade
apt-get -y autoremove --purge
apt-get clean

# ── 2. Container dello stack ─────────────────────────────────
echo "[2/4] Aggiornamento container Docker..."
cd "$REPO_DIR"
docker compose pull
docker compose up -d
docker image prune -f

# ── 3. Health-check ──────────────────────────────────────────
echo "[3/4] Verifica servizi..."
sleep 10
fail=0
for c in pihole unbound npm; do
    state="$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || echo missing)"
    if [[ "$state" == "true" ]]; then
        echo "  [OK]   container $c attivo"
    else
        echo "  [FAIL] container $c NON attivo (stato: $state)"
        fail=1
    fi
done
# Test di risoluzione DNS attraverso Unbound (il resolver privato)
if docker exec unbound drill @127.0.0.1 -p 5335 cloudflare.com &>/dev/null; then
    echo "  [OK]   Unbound risolve i DNS"
else
    echo "  [FAIL] Unbound NON risolve i DNS"
    fail=1
fi
if [[ $fail -ne 0 ]]; then
    echo "  >>> ATTENZIONE: health-check fallito! Controlla: docker compose logs"
fi

# ── 4. Riavvio se richiesto da kernel/firmware ───────────────
echo "[4/4] Controllo riavvio..."
if [[ -f /var/run/reboot-required ]]; then
    if [[ $REBOOT_IF_REQUIRED -eq 1 ]]; then
        echo "  Aggiornamento kernel/firmware: riavvio ora (lo stack riparte da solo)."
        echo "[FINE] $(date '+%H:%M:%S') — reboot in corso"
        /sbin/reboot
        exit 0
    else
        echo "  >>> Riavvio NECESSARIO (kernel/firmware aggiornato)."
        echo "      Riavvia quando vuoi:  sudo reboot"
    fi
else
    echo "  Nessun riavvio necessario."
fi

echo "[FINE] Aggiornamento completato: $(date '+%Y-%m-%d %H:%M:%S')"
[[ $fail -eq 0 ]] && exit 0 || exit 1
