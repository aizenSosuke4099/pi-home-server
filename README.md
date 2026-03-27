# 🏠 Pi Home Server

Stack completo per **Raspberry Pi 4 (2GB)** — blocco pubblicità, DNS privato, VPN e monitoraggio.

## Stack

| Servizio | Funzione |
|---|---|
| **Pi-hole** | Blocco pubblicità a livello rete |
| **Unbound** | DNS resolver locale (no Google/Cloudflare) |
| **WireGuard** | VPN per accesso remoto sicuro |
| **Netdata** | Monitoraggio CPU/RAM/rete (opzionale) |

## Requisiti

- Raspberry Pi 4 (2GB+)
- Raspberry Pi OS Lite 64-bit
- Connessione internet
- IP locale fisso sul Pi (consigliato: impostalo nel router)

## Installazione rapida

```bash
# 1. Clona la repo
git clone https://github.com/aizenSosuke4099/pi-home-server.git
cd pi-home-server

# 2. Esegui lo script (installa Docker + avvia tutto)
sudo bash scripts/install.sh
```

Lo script:
1. Aggiorna il sistema
2. Installa Docker
3. Crea il file `.env` da compilare
4. Avvia tutti i container

## Configurazione manuale

```bash
# Copia e modifica il file di configurazione
cp .env.example .env
nano .env
```

Variabili da impostare:

| Variabile | Descrizione |
|---|---|
| `PIHOLE_PASSWORD` | Password interfaccia web Pi-hole |
| `WG_SERVER_URL` | IP pubblico o dominio (es. DuckDNS) |
| `WG_PEERS` | Numero di client WireGuard da generare |

## Avvio / Stop

```bash
# Avvia tutto
docker compose up -d

# Avvia con Netdata
docker compose --profile monitoring up -d

# Stop
docker compose down

# Log in tempo reale
docker compose logs -f
```

## Aggiornamento

```bash
sudo bash scripts/update.sh
```

## Accesso

| Interfaccia | URL |
|---|---|
| Pi-hole admin | `http://<IP-del-pi>/admin` |
| Netdata | `http://<IP-del-pi>:19999` |
| WireGuard QR client | `docker exec wireguard /app/show-peer peer1` |

## Dopo l'installazione

Imposta il **DNS del router** sull'IP del Raspberry Pi → tutti i dispositivi useranno Pi-hole automaticamente.

## Struttura

```
pi-home-server/
├── docker-compose.yml       # Definizione servizi
├── .env.example             # Template variabili
├── .gitignore
├── unbound/
│   └── unbound.conf         # Config DNS resolver
├── pihole/                  # Dati Pi-hole (gitignored)
├── wireguard/               # Config VPN (gitignored)
└── scripts/
    ├── install.sh           # Installazione completa
    └── update.sh            # Aggiornamento container
```
