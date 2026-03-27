#!/bin/bash
# Aggiorna tutti i container all'ultima versione
set -e
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[INFO] Pull nuove immagini..."
docker compose pull

echo "[INFO] Riavvio stack con nuove immagini..."
docker compose up -d

echo "[INFO] Pulizia immagini vecchie..."
docker image prune -f

echo "[OK] Aggiornamento completato."
