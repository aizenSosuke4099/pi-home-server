#!/bin/bash
# ============================================================
#  Pi Home Server — script di installazione
#  Testato su: Raspberry Pi OS Lite (64-bit), Pi 4 2GB
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── 0. Controllo root ────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Esegui come root: sudo bash install.sh"

# ── 1. Aggiornamento sistema ─────────────────────────────────
info "Aggiornamento pacchetti..."
apt-get update -qq && apt-get upgrade -y -qq

# ── 2. Dipendenze ────────────────────────────────────────────
info "Installazione dipendenze..."
apt-get install -y -qq curl git ca-certificates gnupg lsb-release

# ── 3. Docker ────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    info "Installazione Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "$SUDO_USER"
    info "Docker installato. NOTA: riavvia la sessione per usare docker senza sudo."
else
    info "Docker già installato — skip."
fi

# ── 4. Docker Compose plugin ─────────────────────────────────
if ! docker compose version &>/dev/null; then
    info "Installazione Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin
else
    info "Docker Compose già disponibile — skip."
fi

# ── 5. Abilita IP forwarding (necessario per WireGuard) ──────
info "Abilitazione IP forwarding..."
grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf \
    || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p -q

# ── 6. File .env ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
    warn "File .env creato da .env.example"
    warn "IMPORTANTE: modifica .env con le tue impostazioni prima di continuare!"
    warn "  → nano .env"
    echo ""
    read -rp "Premi INVIO quando hai modificato .env..." _
fi

# ── 7. Avvio stack ───────────────────────────────────────────
info "Avvio dei container..."
docker compose pull -q
docker compose up -d

# ── 8. Riepilogo ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Installazione completata!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Pi-hole admin:  http://$(hostname -I | awk '{print $1}')/admin"
echo "  Netdata:        http://$(hostname -I | awk '{print $1}'):19999  (se attivo)"
echo "  WireGuard QR:   docker exec wireguard /app/show-peer <nome>"
echo ""
info "Imposta il DNS del router su: $(hostname -I | awk '{print $1}')"
