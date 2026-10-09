# WP Next Automation — A–Z VPS install guide

This guide is for someone installing the **full control plane** on their own VPS so they can provision WordPress + Next.js sites with Coolify.

You will end up with:

| Piece | What it is |
|-------|------------|
| Portal | Laravel API + workers (provision, sync, queues) |
| Dashboard | Next.js admin UI |
| Coolify | Your PaaS — runs customer WP + Next apps |
| GitHub | Your account/org — stores Next.js repos |
| Connector plugin | Auto-installed on each new WordPress |

---

## 0. What you need before starting

### VPS

- Ubuntu 22.04 / 24.04 (or similar Linux)
- **≥ 2 GB RAM** (4 GB+ recommended)
- Public IP + DNS (or ngrok for testing)
- Root or sudo access
- Ports **80** and **443** free if you want automatic HTTPS via Caddy

### Already installed elsewhere (not by this installer)

1. **Coolify** on a server you control  
   - Create an API token: Coolify → Keys & Tokens  
   - Note: Server UUID, Project UUID, Environment name, GitHub App UUID (Sources)

2. **GitHub**  
   - Personal account or organization  
   - Ability to create repos (and a Coolify GitHub App installed on that org/user if you use private GitHub App deploys)

3. Optional later: **Stripe**, **SMTP**

### Domains (production)

Point DNS **A records** to the VPS IP, for example:

- `api.yourdomain.com` → portal  
- `app.yourdomain.com` → dashboard  

(Or use one domain with different paths/subdomains — installer asks for two full URLs.)

---

## 1. Install the stack on the VPS

### Linux VPS (recommended)

SSH into the server, then:

```bash
# Download installer (do NOT pipe to bash — interactive TTY required)
curl -fsSL https://raw.githubusercontent.com/boom-devs/wp-next-automation/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

What the script does:

1. Installs **curl / openssl** if missing  
2. Installs **Docker Engine + Compose** if missing (`get.docker.com`)  
3. Asks 3 things:
   - Install directory (default `/opt/wp-next-automation`)
   - **API URL** (`APP_URL`) e.g. `https://api.yourdomain.com`
   - **Dashboard URL** (`FRONTEND_URL`) e.g. `https://app.yourdomain.com`
   - Superadmin email + password  
4. Generates secrets (`APP_KEY`, `JWT_SECRET`, DB password, Reverb keys)  
5. Writes `.env`, `docker-compose.yml`, `Caddyfile`  
6. `docker compose up -d --build`  
7. Runs migrations + seeds the superadmin  

If ports **80/443** are free, **Caddy** is enabled for HTTPS reverse proxy.  
If they are busy, the stack uses host ports (printed at the end) — use those or free 80/443 and reconfigure.

### macOS / local (Docker Desktop)

```bash
# Install Docker Desktop first, then:
curl -fsSL https://raw.githubusercontent.com/boom-devs/wp-next-automation/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

Default install dir: `~/wp-next-automation`.  
For local/ngrok, use URLs like `https://xxxx.ngrok-free.app` for API and a second tunnel/port for the dashboard (or host ports shown after install).

### Re-run / change URLs later

```bash
cd /opt/wp-next-automation   # or your install dir
sudo ./install.sh --reconfigure
```

Or edit `.env` and:

```bash
cd /opt/wp-next-automation
docker compose up -d --build
```

---

## 2. Open the dashboard and log in

1. Open **FRONTEND_URL** in the browser (e.g. `https://app.yourdomain.com`)  
2. Log in with the superadmin email/password from the wizard  
3. You should land on the dashboard  

If login fails: check `docker compose ps` and portal logs:

```bash
cd /opt/wp-next-automation
docker compose ps
docker compose logs portal --tail 100
```

---

## 3. Configure Integrations (required before sites)

Open **Integrations** (superadmin only). Coolify / GitHub / Stripe / Mail are **not** finished by the wizard — configure them here.

### 3.1 Coolify

| Field | Where |
|-------|--------|
| API URL | `https://your-coolify-host` (no `/api/v1` suffix in the UI field) |
| API token | Coolify → Keys & Tokens |
| Server UUID | From Coolify server URL |
| Project UUID | From Coolify project URL |
| GitHub App UUID | Coolify → Sources → private GitHub App (UUID in URL) |
| Environment | Usually `production` |

**Save all** → **Test Coolify**.

### 3.2 GitHub

1. Create a GitHub **OAuth App**  
   - Homepage: dashboard URL  
   - Callback: `{APP_URL}/github/callback` (shown on the Integrations page)  
2. Paste Client ID + Secret  
3. Click **Connect GitHub** (or use a PAT with `repo` scope)  
4. Set **Organization** to your org slug **or** username (personal repos)  
5. Set **Connector plugin repo** (next section)

**Save all** → **Test GitHub**.

### 3.3 Connector plugin (how WordPress gets sync)

The installer does **not** push the plugin into your GitHub.

On each **Add site**, the portal downloads the plugin from:

```text
AWN_PLUGIN_GITHUB_REPO=owner/repo
AWN_PLUGIN_GITHUB_REF=main
```

(Integrations → GitHub → Connector plugin repo / ref)

**For a public / OSS setup:** use a **public** `owner/wp-next-connector` repo so any self-hoster can download it.

**Private fork:** fork the connector into your org, connect a token that can read it, set that `owner/repo`.

If auto-install fails, upload the zip manually in WP Admin and ensure `awn_api_token` matches the site sync token.

### 3.4 Stripe (optional)

Paste publishable + secret keys, webhook:

```text
{APP_URL}/api/stripe/webhook
```

**Test Stripe** → create **Plans** → **Sync Stripe ↔ plans**.

### 3.5 Mail (recommended)

Default is `log` (no real email). For site passwords / resets:

- Integrations → **Mail**
- Mailer: `smtp`
- Host, port, username, password, from address  
- **Save & send test email**

---

## 4. Create your first site

1. Confirm Integrations readiness: Coolify + GitHub ready  
2. **Sites → Add site**  
3. Wait for provisioning (WordPress + GitHub Next.js repo + Coolify Next.js app)  
4. Open WP Admin (credentials emailed if SMTP works)  
5. Edit content → site **Sync**  
6. Portal pushes to GitHub and redeploys Coolify  

---

## 5. Customer / multi-user flow (if you sell access)

1. Configure Stripe + plans  
2. Share `/pricing`  
3. Customers checkout → dashboard → create sites within plan limits  

---

## 6. Day-2 operations

### Useful commands

```bash
cd /opt/wp-next-automation

docker compose ps
docker compose logs -f portal worker
docker compose restart portal worker dashboard

# Shell into portal
docker compose exec portal php artisan tinker
```

### Update / rebuild

If you build from source next to the install:

```bash
docker compose build portal dashboard
docker compose up -d portal worker dashboard scheduler reverb
```

If you use published GHCR images, bump tags in `.env` and:

```bash
docker compose pull
docker compose up -d
```

### Back up

- MySQL volume / DB dump  
- `portal` storage volumes  
- `.env` (secrets)  

---

## 7. Troubleshooting

| Problem | Fix |
|---------|-----|
| `sudo ./install.sh` required on Linux | Run as root |
| Docker missing | Script installs on Linux; Desktop must be installed on Mac |
| Can't open dashboard | Check DNS, Caddy profile, or host ports in install output |
| Coolify test fails | Save URL+token first, then Test |
| GitHub org 404 | Use real org slug or your username |
| Sync fails / no `awn` routes | Connector not installed — fix plugin repo access or install zip manually |
| Push OK, Coolify no rebuild | Portal should POST `/deploy`; check worker logs; manual Deploy in Coolify as fallback |
| No WP password email | Set Mail → smtp |
| Private plugin 403 | Make connector public or use a fork your token can read |

---

## 8. Architecture (mental model)

```text
Browser → Dashboard (FRONTEND_URL)
              ↓ API
         Portal (APP_URL) ──queue──► workers
              ↓                           ↓
         Coolify API              GitHub (Next.js repos)
              ↓
     WordPress + Next.js containers
              ↑
     wp-next-connector (on each WP)
```

---

## Related docs

- [ENVIRONMENT.md](./ENVIRONMENT.md) — env variable reference  
- Portal backend README — Integrations deep dive  
- Connector plugin README — manual install  

## License

MIT — see root [LICENSE](../LICENSE).
