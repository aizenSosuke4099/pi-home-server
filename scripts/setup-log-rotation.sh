#!/bin/bash
# ============================================================
#  Pi Home Server — rotazione dei log dei container Docker
#
#  Imposta in /etc/docker/daemon.json un limite ai log dei container
#  (max 10MB x 3 file ciascuno), così non crescono all'infinito.
#  Il merge è NON distruttivo: eventuali altre impostazioni restano.
#
#  Uso:  sudo bash scripts/setup-log-rotation.sh
# ============================================================
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Esegui come root: sudo bash scripts/setup-log-rotation.sh"; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAEMON="/etc/docker/daemon.json"
mkdir -p /etc/docker

# Backup se il file esiste già
[[ -f "$DAEMON" ]] && cp "$DAEMON" "${DAEMON}.bak.$(date +%Y%m%d%H%M%S)"

# Merge non distruttivo: aggiunge log-driver/log-opts mantenendo le altre chiavi
python3 - "$DAEMON" <<'PY'
import json, os, sys
path = sys.argv[1]
data = {}
if os.path.isfile(path):
    with open(path) as f:
        content = f.read().strip()
    if content:
        try:
            data = json.loads(content)
        except json.JSONDecodeError:
            sys.exit("ERRORE: daemon.json esistente non è JSON valido, interrompo.")
data["log-driver"] = "json-file"
data.setdefault("log-opts", {})
data["log-opts"]["max-size"] = "10m"
data["log-opts"]["max-file"] = "3"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(json.dumps(data, indent=2))
PY

echo "[OK] /etc/docker/daemon.json aggiornato."

echo "Riavvio del demone Docker (i container si riavviano un attimo)..."
systemctl restart docker
for _ in $(seq 1 30); do docker info &>/dev/null && break; sleep 1; done

# Applica la rotazione anche ai container già esistenti, ricreandoli
cd "$REPO_DIR" || { echo "cartella repo non raggiungibile: $REPO_DIR"; exit 1; }
if docker compose ps -q 2>/dev/null | grep -q .; then
    echo "Ricreo i container per applicare la rotazione ai log..."
    if docker ps --format '{{.Names}}' | grep -qx netdata; then
        docker compose --profile monitoring up -d --force-recreate
    else
        docker compose up -d --force-recreate
    fi
fi

echo "[OK] Rotazione log attiva: ogni container al massimo 10MB x3 file."
