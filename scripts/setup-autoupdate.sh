#!/bin/bash
# ============================================================
#  Pi Home Server — installa l'aggiornamento automatico settimanale
#
#  Crea un systemd timer che lancia scripts/update.sh ogni DOMENICA alle 04:00,
#  riavviando il Pi se un aggiornamento di kernel/firmware lo richiede.
#  Lo stack riparte da solo al boot (restart policy + Docker abilitato).
#
#  Uso:  sudo bash scripts/setup-autoupdate.sh
# ============================================================
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Esegui come root: sudo bash scripts/setup-autoupdate.sh"; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GREEN='\033[0;32m'; NC='\033[0m'

# ── Service: cosa eseguire ───────────────────────────────────
cat > /etc/systemd/system/pi-home-update.service <<EOF
[Unit]
Description=Pi Home Server - aggiornamento completo (OS + Docker + container)
Wants=network-online.target docker.service
After=network-online.target docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash ${REPO_DIR}/scripts/update.sh --reboot
EOF

# ── Timer: quando eseguirlo ──────────────────────────────────
cat > /etc/systemd/system/pi-home-update.timer <<'EOF'
[Unit]
Description=Pi Home Server - update settimanale (domenica 04:00)

[Timer]
OnCalendar=Sun *-*-* 04:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now pi-home-update.timer

echo ""
echo -e "${GREEN}[OK] Aggiornamento automatico installato.${NC}"
echo ""
echo "Prossima esecuzione:"
systemctl list-timers pi-home-update.timer --no-pager | sed -n '1,2p'
echo ""
echo "Comandi utili:"
echo "  Stato timer:     systemctl status pi-home-update.timer"
echo "  Lancia ora:      sudo systemctl start pi-home-update.service"
echo "  Log ultimo run:  journalctl -u pi-home-update.service -n 50 --no-pager"
echo "  Log su file:     cat /var/log/pi-home-update.log"
echo "  Disattiva:       sudo systemctl disable --now pi-home-update.timer"
