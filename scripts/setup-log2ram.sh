#!/bin/bash
# ============================================================
#  Pi Home Server — installa log2ram (riduce l'usura della SD card)
#  Tiene /var/log in RAM e lo scrive su SD periodicamente, invece di
#  scriverci di continuo. RICHIEDE UN RIAVVIO per attivarsi.
#  Uso:  sudo bash scripts/setup-log2ram.sh
# ============================================================
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Esegui come root: sudo bash scripts/setup-log2ram.sh"; exit 1; }

if command -v log2ram &>/dev/null; then
    echo "[INFO] log2ram è già installato."
else
    echo "[INFO] Aggiungo il repository azlux e installo log2ram..."
    install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://azlux.fr/repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/azlux-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ stable main" \
        > /etc/apt/sources.list.d/azlux.list
    apt-get update -qq
    apt-get install -y log2ram
fi

echo ""
echo "[OK] log2ram installato. Riavvia per attivarlo:  sudo reboot"
echo "     Verifica dopo il riavvio:  systemctl status log2ram && df -h /var/log"
