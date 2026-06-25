#!/bin/bash
# ============================================================
#  Pi Home Server — installa il backup automatico giornaliero
#  Crea un systemd timer che lancia scripts/backup.sh ogni giorno alle 03:00
#  (un'ora prima dell'update settimanale → restore point sempre fresco).
#  Uso:  sudo bash scripts/setup-backup.sh
# ============================================================
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Esegui come root: sudo bash scripts/setup-backup.sh"; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GREEN='\033[0;32m'; NC='\033[0m'

cat > /etc/systemd/system/pi-home-backup.service <<EOF
[Unit]
Description=Pi Home Server - backup dei dati persistenti
After=docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash ${REPO_DIR}/scripts/backup.sh
EOF

cat > /etc/systemd/system/pi-home-backup.timer <<'EOF'
[Unit]
Description=Pi Home Server - backup giornaliero (03:00)

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now pi-home-backup.timer

echo ""
echo -e "${GREEN}[OK] Backup automatico installato (giornaliero, 03:00).${NC}"
systemctl list-timers pi-home-backup.timer --no-pager | sed -n '1,2p'
echo ""
echo "Comandi utili:"
echo "  Backup di prova ora:  sudo systemctl start pi-home-backup.service"
echo "  Log:                  cat /var/log/pi-home-backup.log"
echo "  Disattiva:            sudo systemctl disable --now pi-home-backup.timer"
