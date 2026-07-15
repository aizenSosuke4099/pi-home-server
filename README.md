# Pi Home Server

Stack per **Raspberry Pi 4 (2GB)** — blocco pubblicità, tracking, malware e phishing a livello rete + DNS privato + dashboard e monitoraggio. Tutto in Docker, tutto in un comando.

```
Pi-hole ──────→ blocca ads, tracking, malware e phishing per ogni dispositivo
Unbound ──────→ risolve i DNS localmente, senza passare da Google/Cloudflare
NPM ──────────→ reverse proxy HTTPS con certificato Let's Encrypt
Homepage ─────→ dashboard unica con tutti i servizi
Uptime Kuma ──→ monitora se i servizi sono online
Auto-update ──→ aggiorna OS + Docker + container ogni domenica notte (systemd)
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
4. Configura la rotazione dei log dei container
5. Scarica le immagini Docker e avvia i container
6. Importa liste, allowlist e regex deny in Pi-hole

---

## Configurazione

Prima di avviare (o se non hai usato `install.sh`), copia e modifica il file `.env`:

```bash
cp .env.example .env
nano .env
```

| Variabile | Esempio | Descrizione |
|---|---|---|
| `PI_IP` | `192.168.1.40` | IP locale fisso del Raspberry Pi |
| `PIHOLE_PASSWORD` | `miapassword` | Password per Pi-hole (usata anche da Homepage per i widget) |
| `WG_SERVER_URL` | `nome.duckdns.org` | IP pubblico o dominio DuckDNS. `auto` lo rileva da solo |
| `WG_PEERS` | `3` | Numero di client VPN (uno per dispositivo) |
| `DUCKDNS_SUBDOMAIN` | `nome` | Solo il nome, senza `.duckdns.org` |
| `DUCKDNS_TOKEN` | `a7c4d0ad-...` | Token dalla pagina [duckdns.org](https://www.duckdns.org) |

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
| NPM Admin | `http://<IP-del-pi>:81` | Gestione reverse proxy e certificati HTTPS |
| Homepage | `https://home.<subdomain>.duckdns.org` | Dashboard unica con tutti i servizi |
| Pi-hole | `https://pihole.<subdomain>.duckdns.org` | Gestione blocco DNS |
| Uptime Kuma | `https://kuma.<subdomain>.duckdns.org` | Monitoraggio uptime servizi |
| Netdata | `https://netdata.<subdomain>.duckdns.org` | CPU, RAM, temperatura (se attivo) |

Sostituisci `<IP-del-pi>` con l'indirizzo locale del tuo Raspberry (es. `192.168.1.40`).

> **Nota**: Chrome potrebbe forzare HTTPS sugli indirizzi IP. Usa Safari o Firefox, oppure disabilita "HTTPS Upgrades" in `chrome://flags`.

### Servizi automatici

| Servizio | Cosa fa |
|---|---|
| **Auto-update** | Ogni domenica alle 4:00 aggiorna sistema operativo, engine Docker e container, e riavvia il Pi se serve (vedi [Aggiornamento](#aggiornamento)) |
| **Pi-hole Gravity** | Aggiorna le liste di blocco automaticamente una volta alla settimana |

Non serve fare nulla, girano da soli.

---

## Dopo l'installazione

### 1. Imposta il DNS sul router

Entra nel pannello del router → cerca "DNS primario" nella sezione DHCP → inserisci l'IP del Raspberry Pi.

In questo modo **tutti i dispositivi della rete** (TV, telefoni, PC) useranno automaticamente Pi-hole senza configurare nulla sui singoli dispositivi.

> ⚠️ **Attenzione all'IPv6:** questo stack lavora in IPv4. Se il router distribuisce anche un **DNS IPv6**, i dispositivi possono aggirare Pi-hole via IPv6 e gli ads ripassano. Nel pannello del router: disabilita il DNS IPv6 (o l'IPv6 del tutto se non ti serve), oppure imposta come DNS IPv6 un indirizzo non risolvente.

### 2. Configura Homepage

Homepage si apre su `http://<IP-del-pi>:3000`. **Non serve modificare nulla a mano**: IP e sottodominio nei link vengono presi dal `.env` tramite le variabili `HOMEPAGE_VAR_PI_IP` e `HOMEPAGE_VAR_DUCKDNS`. I widget di Pi-hole, Uptime Kuma e Netdata funzionano da soli.

> Il meteo in `homepage/config/widgets.yaml` punta a Villafranca di Verona — cambia `latitude`/`longitude` con le tue coordinate. Il link "Router" nei bookmark è `192.168.1.1`: correggilo se il tuo gateway è diverso.

### 3. Configura Uptime Kuma

Vai su `http://<IP-del-pi>:3001`, crea un account al primo accesso, poi aggiungi i monitor:

| Monitor | Tipo | Impostazioni |
|---|---|---|
| Pi-hole | HTTP(s) | URL: `http://<IP-del-pi>/admin` |
| Unbound | DNS | Hostname: `google.com`, Server: `172.20.0.3`, Porta: `5335` |
| Homepage | HTTP(s) | URL: `http://<IP-del-pi>:3000` |

### 4. Configura Nginx Proxy Manager (HTTPS)

Vai su `http://<IP-del-pi>:81` e accedi con le credenziali di default:
- Email: `admin@example.com`
- Password: `changeme`

Cambia subito email e password al primo login.

#### Aggiungere un servizio HTTPS

Per ogni servizio (Pi-hole, Homepage, Kuma, Netdata):

1. **Proxy Hosts** → Add Proxy Host
2. **Domain Names**: `pihole.<subdomain>.duckdns.org`
3. **Forward Hostname**: `pihole` (nome del container)
4. **Forward Port**: `80` (porta interna del container)
5. Tab **SSL** → Request a new SSL Certificate → Force SSL → Save

| Servizio | Domain | Forward Host | Forward Port |
|---|---|---|---|
| Pi-hole | `pihole.<sub>.duckdns.org` | `pihole` | `80` |
| Homepage | `home.<sub>.duckdns.org` | `homepage` | `3000` |
| Uptime Kuma | `kuma.<sub>.duckdns.org` | `uptime-kuma` | `3001` |
| Netdata | `netdata.<sub>.duckdns.org` | `netdata` | `19999` |

> **Nota**: Per i certificati DuckDNS usa la DNS Challenge: SSL → Use a DNS Challenge → DuckDNS → inserisci il tuo token.

### 5. Configura WireGuard

Dopo l'avvio, mostra il QR code per connettere i dispositivi:

```bash
# QR code per il primo dispositivo
sudo docker exec wireguard /app/show-peer peer1

# Per il secondo
sudo docker exec wireguard /app/show-peer peer2
```

Scansiona il QR con l'app **WireGuard** (iOS / Android). Per usare WireGuard da fuori casa, apri la porta nel router:

| Campo | Valore |
|---|---|
| Porta | `40959` |
| Protocollo | **UDP** |
| IP destinazione | IP del Pi |

### 6. Port forwarding sul router

Aggiungi un reindirizzamento porte nel pannello del router per WireGuard:
- Porta esterna/interna: `40959`
- Protocollo: `UDP`
- Destinazione: IP del Pi

> ⚠️ **Inoltra dall'esterno solo la `40959/UDP`** (e, solo se usi i certificati Let's Encrypt in HTTP-01, le `80`/`443/TCP`). **Non** esporre mai su Internet i pannelli admin: `81` (NPM), `3000` (Homepage), `3001` (Kuma), `19999` (Netdata). Restano raggiungibili dalla LAN o, da fuori, tramite la VPN WireGuard.

---

## Liste di blocco

Lo script `setup-adlists.sh` importa **~30 liste** da `pihole/adlists.txt`. La scelta è volutamente **snella**: Hagezi Ultimate copre già ads+tracking di decine di liste, quindi qui restano solo quelle che Ultimate *non* include:

| Categoria | Fonti |
|---|---|
| Ads + tracking (catch-all) | Hagezi Ultimate |
| Malware / phishing | Hagezi TIF, DandelionSprout, malware-filter, phishing.army, abuse.ch, Firebog RPiList/Prigent |
| Ransomware / crypto / stalkerware | BlocklistProject, Firebog Prigent-Crypto, AssoEchap |
| Scam / fraud / spam | Spam404, durablenapkin, jarelllama, BlocklistProject fraud/scam |
| Telemetria per brand | Hagezi native (Amazon, Apple, Samsung, Huawei, Xiaomi, LG webOS, Win/Office, TikTok) + WindowsSpyBlocker |
| Smart TV / Android / Fire TV | Perflyst SmartTV, Android tracking, Amazon Fire TV |
| DNS bypass (DoH) | Hagezi DoH |

Si superano comunque i **4M+ domini bloccati**, e le liste si aggiornano da sole una volta alla settimana.

> **Perché ~30 e non 51?** Impilare più tier Hagezi (multi+pro+ultimate) o decine di liste-ads sovrapposte **non** aumenta il blocco — Ultimate le contiene già — ma appesantisce la gravity sul Pi 2GB e moltiplica i falsi positivi. Meno ridondanza = stesso blocco reale, Pi più leggero.

Lo stesso script importa anche `pihole/allowlist.txt` (allow esatti) e `pihole/regex-blocklist.txt` (regex deny). Per aggiungere/rimuovere una regola, modifica il file corrispondente e riesegui:

```bash
sudo bash scripts/setup-adlists.sh
```

> Se un sito non funziona, vai su **Query Log** → trova la richiesta bloccata → clicca per aggiungerla alla allowlist.

### Allowlist

Alcuni domini vanno sbloccati perché necessari ai servizi: sono in `pihole/allowlist.txt` (allow esatti) e li importa automaticamente `setup-adlists.sh`. Tra questi: `graph.facebook.com`, `dit.whatsapp.net`, `firetvcaptiveportal.com`, `xp.apple.com`, `firebaseinstallations.googleapis.com`.

Le regex di telemetria che le liste non coprono sono in `pihole/regex-blocklist.txt` (importate come Regex deny).

---

## Aggiornamento

Lo script `scripts/update.sh` aggiorna **tutto** in un colpo: pacchetti del sistema operativo, engine Docker (`docker-ce`) e immagini dei container. Fa anche un health-check finale e scrive il log in `/var/log/pi-home-update.log`.

### Aggiornamento manuale

```bash
sudo bash scripts/update.sh
```

Se un aggiornamento di kernel/firmware richiede un riavvio, te lo segnala (manualmente non riavvia da solo): `sudo reboot` quando vuoi.

### Aggiornamento automatico settimanale

Per farlo girare da solo ogni **domenica alle 4:00** (con riavvio automatico se serve — lo stack riparte da solo al boot):

```bash
sudo bash scripts/setup-autoupdate.sh
```

Installa un **systemd timer**. Comandi utili dopo l'installazione:

```bash
systemctl status pi-home-update.timer          # stato e prossima esecuzione
sudo systemctl start pi-home-update.service     # lancia subito un aggiornamento
journalctl -u pi-home-update.service -n 50      # log dell'ultimo run
sudo systemctl disable --now pi-home-update.timer   # disattiva
```

> **Nota sul riavvio:** conviene impostare nel router un DNS secondario (es. il router stesso) oltre al Pi, così durante il breve riavvio notturno la rete non resta senza DNS.

### Rotazione dei log dei container

Per evitare che i log dei container crescano all'infinito, `install.sh` configura la rotazione in `/etc/docker/daemon.json` (max 10MB x3 file per container). Su un'installazione già esistente la attivi con:

```bash
sudo bash scripts/setup-log-rotation.sh
```

Il merge è non distruttivo (mantiene eventuali altre impostazioni del demone) e ricrea i container per applicarla.

> **Limiti di RAM:** lo stack mette un tetto di RAM su Netdata e Uptime Kuma per proteggere il Pi da 2GB da un container impazzito. Perché venga davvero applicato, su Raspberry Pi OS può servire abilitare il cgroup memory: aggiungi `cgroup_enable=memory cgroup_memory=1` in fondo (stessa riga) a `/boot/firmware/cmdline.txt` (o `/boot/cmdline.txt` sui sistemi più vecchi) e riavvia.

---

## Backup e ripristino

I dati critici (config NPM, **chiavi WireGuard**, impostazioni Pi-hole, certificati) vivono su SD card: un guasto = tutto perso. Lo script `backup.sh` salva tutti i bind-mount + `.env` in un archivio `tar.gz` datato, con rotazione.

### Backup manuale

```bash
sudo bash scripts/backup.sh
```

Configura nel `.env` destinazione e ritenzione — la destinazione dovrebbe stare su una **USB o un NAS**, non sulla SD stessa (altrimenti non protegge da un guasto della scheda):

```
BACKUP_DEST=/mnt/usb/pi-home-backup
BACKUP_KEEP=7
```

### Backup automatico giornaliero

```bash
sudo bash scripts/setup-backup.sh
```

Installa un systemd timer (ogni giorno alle 03:00, un'ora prima dell'update settimanale → hai sempre un restore point fresco prima degli aggiornamenti).

### Ripristino

```bash
sudo docker compose down                                      # 1. ferma lo stack
sudo tar -xzf /percorso/pi-home-backup-AAAAMMGG-HHMMSS.tar.gz -C ~/pi-home-server   # 2. estrai
sudo docker compose up -d                                     # 3. riavvia
```

> Il backup **esclude** i database rigenerabili di Pi-hole (`gravity.db`, lo storico query FTL): sono grossi e si ricreano da soli. Dopo un ripristino, Pi-hole riscarica le liste al primo gravity update — o subito con `sudo docker exec pihole pihole -g`. Il blocco DNS torna identico (liste, allow e regex sono nel backup e nella repo).

---

## Notifiche

Per essere avvisato quando un **aggiornamento o un backup fallisce**, imposta un topic [ntfy.sh](https://ntfy.sh) nel `.env` e iscriviti dall'app (nessun account richiesto):

```
NTFY_TOPIC=pi-home-un-nome-difficile-da-indovinare
```

Lascialo vuoto per disattivare le notifiche.

---

## Usura della SD card

Pi-hole scrive il query log di continuo: per allungare la vita della SD, `log2ram` tiene `/var/log` in RAM e lo scrive su scheda solo periodicamente.

```bash
sudo bash scripts/setup-log2ram.sh
sudo reboot
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

Verifica che `PI_IP` nel `.env` corrisponda all'IP del tuo Pi. Dopo aver corretto, riavvia con `sudo docker compose up -d`.

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
│   ├── adlists.txt          <- ~30 liste di blocco pre-configurate
│   ├── regex-blocklist.txt  <- regex deny per telemetria e tracking
│   ├── allowlist.txt        <- domini sbloccati (Facebook, Fire TV)
│   └── etc-pihole/          <- dati Pi-hole (generati al primo avvio, gitignored)
|
├── homepage/
│   └── config/              <- configurazione dashboard Homepage
|
├── npm/
│   ├── data/                <- config NPM (gitignored)
│   └── letsencrypt/         <- certificati SSL (gitignored)
|
├── uptime-kuma/
│   └── data/                <- dati Uptime Kuma (gitignored)
|
└── scripts/
    ├── install.sh           <- installazione completa (Docker + avvio stack)
    ├── setup-adlists.sh     <- importa liste + allowlist + regex in Pi-hole
    ├── setup-autoupdate.sh  <- installa l'aggiornamento automatico settimanale
    ├── setup-backup.sh      <- installa il backup automatico giornaliero
    ├── setup-log-rotation.sh<- limita i log dei container (10MB x3 ciascuno)
    ├── setup-log2ram.sh     <- riduce l'usura della SD (log in RAM)
    ├── backup.sh            <- backup dei dati persistenti (tar.gz, con rotazione)
    ├── notify.sh            <- notifiche via ntfy (usato da update/backup)
    └── update.sh            <- aggiorna OS + Docker engine + container (con log)
```

---

## Come funziona

```
Dispositivo -> Router -> Pi-hole -> Unbound -> Internet
                            |
                      blocca ads, tracking,       Browser -> NPM (443) -> Servizio
                      malware e phishing                      |
                      prima che partano              HTTPS con Let's Encrypt
```

1. Il **router** manda tutte le richieste DNS al Pi
2. **Pi-hole** controlla se il dominio e' in una delle liste di blocco → se si, blocca
3. Se non e' bloccato, passa la richiesta a **Unbound**
4. **Unbound** risolve direttamente i DNS interrogando i root server, senza passare da Google o Cloudflare
5. L'**auto-update** settimanale tiene aggiornati OS, Docker e container
6. **Homepage** mostra lo stato di tutti i servizi in una dashboard unica
