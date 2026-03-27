# 🏠 Pi Home Server

Stack completo per **Raspberry Pi 4 (2GB)** — blocco pubblicità a livello rete, DNS privato, VPN per accesso remoto e monitoraggio. Tutto in Docker, tutto in un comando.

```
Pi-hole ──→ blocca pubblicità per ogni dispositivo della rete
Unbound ──→ risolve i DNS localmente, senza passare da Google/Cloudflare
WireGuard ─→ VPN: usi Pi-hole anche fuori casa
Netdata ───→ dashboard CPU/RAM/rete in tempo reale (opzionale)
```

---

## Indice

- [Requisiti](#requisiti)
- [Installazione rapida](#installazione-rapida)
- [Configurazione](#configurazione)
- [Uso quotidiano](#uso-quotidiano)
- [Connettere i client WireGuard](#connettere-i-client-wireguard)
- [Dopo l'installazione](#dopo-linstallazione)
- [Aggiornamento](#aggiornamento)
- [Troubleshooting](#troubleshooting)
- [Struttura del progetto](#struttura-del-progetto)

---

## Requisiti

| Cosa | Dettaglio |
|---|---|
| Hardware | Raspberry Pi 4 (2GB RAM o più) |
| Sistema operativo | Raspberry Pi OS Lite **64-bit** |
| IP locale fisso | Impostalo nel router (DHCP reservation sull'indirizzo MAC del Pi) |
| Porta aperta sul router | `51820/UDP` → per WireGuard dall'esterno |

> **Perché IP fisso?** Il router deve sapere sempre dove trovare il Pi per instradare il DNS. Senza IP fisso, Pi-hole smette di funzionare al primo riavvio del router.

---

## Installazione rapida

```bash
# 1. Clona la repo sul Raspberry Pi
git clone https://github.com/aizenSosuke4099/pi-home-server.git
cd pi-home-server

# 2. Lancia lo script — installa Docker e avvia tutto
sudo bash scripts/install.sh
```

Lo script fa tutto in automatico:
1. Aggiorna il sistema operativo
2. Installa Docker e Docker Compose
3. Abilita l'IP forwarding (necessario per WireGuard)
4. Chiede di compilare il file `.env` con le tue impostazioni
5. Scarica le immagini Docker e avvia i container

---

## Configurazione

Prima di avviare (o se non hai usato `install.sh`), copia e modifica il file `.env`:

```bash
cp .env.example .env
nano .env
```

| Variabile | Esempio | Descrizione |
|---|---|---|
| `PIHOLE_PASSWORD` | `miapassword` | Password per l'interfaccia web di Pi-hole |
| `WG_SERVER_URL` | `auto` oppure `pippo.duckdns.org` | IP pubblico o dominio DuckDNS. `auto` lo rileva da solo |
| `WG_PEERS` | `3` | Numero di client VPN da generare (uno per dispositivo: telefono, laptop, ecc.) |

> **DuckDNS** è un servizio gratuito per avere un dominio fisso anche con IP pubblico dinamico. Registrati su [duckdns.org](https://www.duckdns.org) e usa il dominio come `WG_SERVER_URL`.

---

## Uso quotidiano

```bash
# Avvia tutto lo stack
docker compose up -d

# Avvia con Netdata (monitoraggio)
docker compose --profile monitoring up -d

# Ferma tutto
docker compose down

# Riavvia un singolo servizio
docker compose restart pihole

# Controlla lo stato dei container
docker compose ps

# Log in tempo reale (tutti i servizi)
docker compose logs -f

# Log di un singolo servizio
docker compose logs -f pihole
```

### Interfacce web

| Servizio | URL |
|---|---|
| Pi-hole (admin) | `http://<IP-del-pi>/admin` |
| Netdata (monitoraggio) | `http://<IP-del-pi>:19999` |

Sostituisci `<IP-del-pi>` con l'indirizzo locale del tuo Raspberry (es. `192.168.1.100`).

---

## Connettere i client WireGuard

WireGuard genera automaticamente le configurazioni per ogni client (peer).

### Da telefono (QR code)

```bash
# Mostra il QR code per il primo client
docker exec wireguard /app/show-peer peer1

# Per il secondo client
docker exec wireguard /app/show-peer peer2
```

Scansiona il QR code con l'app **WireGuard** (iOS / Android).

### Da computer (file di configurazione)

```bash
# Copia il file di configurazione sul tuo computer
scp pi@<IP-del-pi>:~/pi-home-server/wireguard/config/peer1/peer1.conf ~/Desktop/
```

Importa il file nell'app WireGuard sul tuo computer.

> Una volta connesso alla VPN, tutto il traffico passa per Pi-hole → pubblicità bloccata anche fuori casa.

---

## Dopo l'installazione

### Imposta il DNS sul router

Entra nel pannello del router → cerca "DNS primario" → inserisci l'IP del Raspberry Pi.

In questo modo **tutti i dispositivi della rete** (TV, telefoni, PC) useranno automaticamente Pi-hole senza configurare nulla sui singoli dispositivi.

### Aggiungi liste di blocco extra su Pi-hole

1. Vai su `http://<IP-del-pi>/admin`
2. Login con la password impostata nel `.env`
3. **Group Management → Adlists** → aggiungi le liste che vuoi

Liste consigliate:
- `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` (già inclusa)
- `https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt`
- `https://blocklistproject.github.io/Lists/tracking.txt`

---

## Aggiornamento

```bash
sudo bash scripts/update.sh
```

Scarica le nuove versioni dei container, riavvia lo stack e pulisce le immagini vecchie.

---

## Troubleshooting

### Pi-hole non risolve i siti (solo blocca tutto)

Unbound potrebbe non essere partito. Controlla:

```bash
docker compose logs unbound
docker compose restart unbound
```

### WireGuard non si connette dall'esterno

- Verifica che la porta `51820/UDP` sia aperta nel router (port forwarding → IP del Pi)
- Controlla che `WG_SERVER_URL` nel `.env` sia il tuo IP pubblico corretto:
  ```bash
  curl ifconfig.me
  ```

### Pi-hole non vede le richieste DNS dei dispositivi

Il router non sta usando Pi-hole come DNS. Verifica le impostazioni DNS nel pannello del router.

### Vedo i container ma non riesco ad accedere all'interfaccia web

```bash
# Controlla che i container siano running
docker compose ps

# Controlla i log di Pi-hole
docker compose logs pihole
```

---

## Struttura del progetto

```
pi-home-server/
│
├── docker-compose.yml       ← definizione dell'intero stack
├── .env.example             ← template variabili (copia in .env)
├── .gitignore               ← esclude .env e dati runtime
│
├── unbound/
│   └── unbound.conf         ← configurazione DNS resolver locale
│
├── pihole/                  ← dati Pi-hole (generati al primo avvio, gitignored)
├── wireguard/               ← configurazioni VPN (generati al primo avvio, gitignored)
│
└── scripts/
    ├── install.sh           ← installazione completa (Docker + avvio stack)
    └── update.sh            ← aggiornamento container
```

---

## Come funziona (in breve)

```
Dispositivo → Router → Pi-hole → Unbound → Internet
                          ↓
                    blocca le pubblicità
                    prima che partano
```

1. Il **router** manda tutte le richieste DNS al Pi
2. **Pi-hole** controlla se il dominio è nella lista nera → se sì, blocca
3. Se non è bloccato, passa la richiesta a **Unbound**
4. **Unbound** risolve direttamente i DNS senza passare da Google o Cloudflare

Con **WireGuard** attivo sul telefono, lo stesso percorso vale anche fuori casa.
