# WP Next Automation

Open-source control plane for WordPress + Next.js sites on **your** Coolify, with a web dashboard and optional Stripe subscriptions.

**Full A–Z VPS guide:** [docs/INSTALL.md](docs/INSTALL.md)

---

## Quick start (Linux VPS)

```bash
curl -fsSL https://raw.githubusercontent.com/boom-devs/wp-next-automation/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

Do **not** use `curl | bash` — the installer is interactive (TTY required).

Wizard asks for:

1. Install directory  
2. API URL + dashboard URL  
3. Superadmin email + password  

Secrets are auto-generated. Docker Compose starts portal, dashboard, DB, Redis, workers, and seeds the superadmin.

| Platform | Notes |
|----------|--------|
| Linux VPS | Script can install Docker Engine + Compose |
| macOS | Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) first, then `./install.sh` (no sudo) |
| Windows | Use **WSL2** + Docker Desktop, then same as Linux |

---

## After install (required)

1. Open the **dashboard URL** → log in as superadmin  
2. **Integrations** → configure:
   - **Coolify** (API URL, token, server/project/GitHub App UUIDs)
   - **GitHub** (OAuth Connect or PAT + org/username)
   - **Connector plugin repo** (`owner/wp-next-connector` — prefer a **public** repo for OSS)
   - **Stripe** (optional)
   - **Mail → smtp** (optional but needed for real credential emails)
3. **Sites → Add site** → then **Sync** after editing WordPress  

Step-by-step screens and troubleshooting: **[docs/INSTALL.md](docs/INSTALL.md)**  
Env reference: **[docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)**

---

## How the WordPress connector reaches each site

Install does **not** push the plugin into each user’s GitHub.

On provision, the portal downloads the zip from `AWN_PLUGIN_GITHUB_REPO` / Integrations and installs it on that WordPress. Self-hosters should point that setting at a repo **they can read** (public upstream or their own fork).

---

## Components

| Path | Role |
|------|------|
| This repo | `install.sh` + Compose + docs |
| Backend (portal) | Laravel API / queues / Coolify |
| Dashboard | Next.js UI |
| Plugin | WordPress connector |

---

## Customer flow (with Stripe)

1. Configure Stripe + plans in the dashboard  
2. Share `/pricing`  
3. Customer checks out → creates sites in their account  

Webhook: `{APP_URL}/api/stripe/webhook`

---

## License

MIT — see [LICENSE](LICENSE).
