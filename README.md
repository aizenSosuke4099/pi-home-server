# Pi Home Server

Stack per **Raspberry Pi 4 (2GB)** — blocco pubblicità, tracking, malware e phishing a livello rete + DNS privato + dashboard e monitoraggio. Tutto in Docker, tutto in un comando.

```
Pi-hole ──────→ blocca ads, tracking, malware e phishing per ogni dispositivo
Unbound ──────→ risolve i DNS localmente, senza passare da Google/Cloudflare
Homepage ─────→ dashboard unica con tutti i servizi
Uptime Kuma ──→ monitora se i servizi sono online
Watchtower ───→ aggiorna i container automaticamente ogni notte
Netdata ──────→ dashboard CPU/RAM/rete in tempo reale (opzionale)
```

---

## Indice

- [Requisiti](#requisiti)
- [Installazione rapida](#installazione-rapida)
- [Configurazione](#configurazione)
- [Uso quotidiano](#uso-quotidiano)
- [Dopo l'installazione](#dopo-linstallazione)
- [Liste di blocco](#liste-di-blocco)
- [Uptime Kuma](#uptime-kuma)
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
3. Chiede di compilare il file `.env` con le tue impostazioni
4. Scarica le immagini Docker e avvia i container
5. Importa 52 liste di blocco in Pi-hole

---

## Configurazione

Prima di avviare (o se non hai usato `install.sh`), copia e modifica il file `.env`:

```bash
cp .env.example .env
nano .env
```

| Variabile | Esempio | Descrizione |
|---|---|---|
| `PIHOLE_PASSWORD` | `miapassword` | Password per Pi-hole (usata anche da Homepage per i widget) |

---

## Uso quotidiano

```bash
# Avvia lo stack
sudo docker compose up -d

# Avvia con Netdata (monitoraggio hardware)
sudo docker compose --profile monitoring up -d

# Ferma tutto
sudo docker compose down

# Riavvia un singolo servizio
sudo docker compose restart pihole

# Controlla lo stato dei container
sudo docker compose ps

# Log in tempo reale
sudo docker compose logs -f

# Log di un singolo servizio
sudo docker compose logs -f pihole
```

### Interfacce web

| Servizio | URL | Descrizione |
|---|---|---|
| Homepage | `http://<IP-del-pi>:3000` | Dashboard unica con tutti i servizi |
| Pi-hole | `http://<IP-del-pi>/admin` | Gestione blocco DNS |
| Uptime Kuma | `http://<IP-del-pi>:3001` | Monitoraggio uptime servizi |
| Netdata | `http://<IP-del-pi>:19999` | CPU, RAM, temperatura (se attivo) |

Sostituisci `<IP-del-pi>` con l'indirizzo locale del tuo Raspberry (es. `192.168.1.40`).

> **Nota**: Chrome potrebbe forzare HTTPS sugli indirizzi IP. Usa Safari o Firefox, oppure disabilita "HTTPS Upgrades" in `chrome://flags`.

### Servizi automatici

| Servizio | Cosa fa |
|---|---|
| **Watchtower** | Aggiorna tutti i container ogni notte alle 4:00 e pulisce le immagini vecchie |
| **Pi-hole Gravity** | Aggiorna le liste di blocco automaticamente una volta alla settimana |

Non serve fare nulla, girano da soli.

---

## Dopo l'installazione

### 1. Imposta il DNS sul router

Entra nel pannello del router → cerca "DNS primario" nella sezione DHCP → inserisci l'IP del Raspberry Pi.

In questo modo **tutti i dispositivi della rete** (TV, telefoni, PC) useranno automaticamente Pi-hole senza configurare nulla sui singoli dispositivi.

### 2. Configura Homepage

Homepage si apre su `http://<IP-del-pi>:3000` ed e' gia' configurata con i widget di Pi-hole, Uptime Kuma e Netdata. La password di Pi-hole viene letta automaticamente dal `.env`.

### 3. Configura Uptime Kuma

Vai su `http://<IP-del-pi>:3001`, crea un account al primo accesso, poi aggiungi i monitor:

| Monitor | Tipo | Impostazioni |
|---|---|---|
| Pi-hole | HTTP(s) | URL: `http://<IP-del-pi>/admin` |
| Unbound | DNS | Hostname: `google.com`, Server: `172.20.0.3`, Porta: `5335` |
| Homepage | HTTP(s) | URL: `http://<IP-del-pi>:3000` |

---

## Liste di blocco

Lo script `install.sh` importa automaticamente **52 liste** da `pihole/adlists.txt`, coprendo:

| Categoria | Fonti |
|---|---|
| Ads | Hagezi Pro/Multi, AdGuard, Easylist, AdAway, Admiral, anudeepND, yoyo |
| Tracking | Easyprivacy, Firebog Prigent, frogeye first/multiparty, BlocklistProject |
| Smart TV / Android | Perflyst SmartTV, Android tracking, Amazon Fire TV |
| Telemetria per brand | Samsung, Apple, Amazon, Huawei, Xiaomi, LG webOS, Windows/Office, TikTok |
| Malware / phishing | Hagezi TIF, DandelionSprout, phishing.army, Firebog RPiList, abuse.ch, stalkerware |
| Spam / scam / fraud | Spam404, durablenapkin, jarelllama, BlocklistProject fraud/scam |
| DNS bypass / crypto | Hagezi DoH, DoH-VPN-proxy-bypass |
| Catch-all | Hagezi Ultimate |

Con tutte le liste attive si superano i **2.5M+ domini bloccati**. Le liste si aggiornano automaticamente una volta alla settimana.

Per aggiungere o rimuovere liste, modifica `pihole/adlists.txt` e riesegui:

```bash
sudo bash scripts/setup-adlists.sh
```

> Se un sito non funziona, vai su **Query Log** → trova la richiesta bloccata → clicca per aggiungerla alla allowlist.

---

## Aggiornamento

I container si aggiornano automaticamente grazie a **Watchtower** (ogni notte alle 4:00).

Per un aggiornamento manuale:

```bash
sudo bash scripts/update.sh
```

---

## Troubleshooting

### Pi-hole non risolve i siti (blocca tutto)

Unbound potrebbe non essere partito. Controlla:

```bash
sudo docker compose logs unbound
sudo docker compose restart unbound
```

### Pi-hole non vede le richieste DNS dei dispositivi

Il router non sta usando Pi-hole come DNS. Verifica le impostazioni DNS nel pannello del router (sezione DHCP → DNS primario → IP del Pi).

### Non riesco ad accedere all'interfaccia web

```bash
# Controlla che i container siano running
sudo docker compose ps

# Controlla i log di Pi-hole
sudo docker compose logs pihole

# Verifica che Pi-hole risponda
curl -I http://localhost/admin/
```

### Chrome non apre la pagina di Pi-hole

Chrome forza HTTPS sugli IP locali. Usa Safari/Firefox oppure disabilita "HTTPS Upgrades" in `chrome://flags`.

### Homepage mostra "Host validation failed"

Verifica che `HOMEPAGE_ALLOWED_HOSTS` nel docker-compose includa il tuo IP. Se hai un IP diverso da `192.168.1.40`, modificalo nel docker-compose e nel file `homepage/config/services.yaml`.

### Permessi negati su git pull

Docker crea file come root. Risolvi con:

```bash
sudo chown -R pi:pi ~/pi-home-server
git stash
git pull
```

---

## Struttura del progetto

```
pi-home-server/
|
├── docker-compose.yml       <- definizione dell'intero stack
├── .env.example             <- template variabili (copia in .env)
├── .gitignore               <- esclude .env e dati runtime
|
├── unbound/
│   └── unbound.conf         <- configurazione DNS resolver locale
|
├── pihole/
│   ├── adlists.txt          <- 52 liste di blocco pre-configurate
│   └── etc-pihole/          <- dati Pi-hole (generati al primo avvio, gitignored)
|
├── homepage/
│   └── config/              <- configurazione dashboard Homepage
|
├── uptime-kuma/
│   └── data/                <- dati Uptime Kuma (gitignored)
|
└── scripts/
    ├── install.sh           <- installazione completa (Docker + avvio stack)
    ├── setup-adlists.sh     <- importa le liste di blocco in Pi-hole
    └── update.sh            <- aggiornamento container
```

---

## Come funziona

```
Dispositivo -> Router -> Pi-hole -> Unbound -> Internet
                            |
                      blocca ads, tracking,
                      malware e phishing
                      prima che partano
```

1. Il **router** manda tutte le richieste DNS al Pi
2. **Pi-hole** controlla se il dominio e' in una delle liste di blocco → se si, blocca
3. Se non e' bloccato, passa la richiesta a **Unbound**
4. **Unbound** risolve direttamente i DNS interrogando i root server, senza passare da Google o Cloudflare
5. **Watchtower** aggiorna tutto automaticamente ogni notte
6. **Homepage** mostra lo stato di tutti i servizi in una dashboard unica
