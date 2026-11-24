# WP Next Automation - Troubleshooting Guide

Use this guide when an install, a login, an integration test, or a site sync fails.
Start with [Quick diagnostics](#quick-diagnostics), then find your symptom below.
Each entry gives the symptom, the likely cause, and the fix that matches how
this repository actually behaves. Commands assume your install directory is
`/opt/wp-next-automation` on a VPS, or `~/wp-next-automation` on macOS; change
the path if you installed elsewhere.

Related docs: [INSTALL.md](./INSTALL.md) (full install guide),
[ENVIRONMENT.md](./ENVIRONMENT.md) (environment variables),
[CONNECTOR_PLUGIN.md](./CONNECTOR_PLUGIN.md) (WordPress connector plugin).

## Quick diagnostics

Run these first. They tell you whether the problem is the stack, the network,
or an integration, before you change anything.

```bash
cd /opt/wp-next-automation

# Are the containers up and healthy?
docker compose ps

# What did the portal and the queue workers just do?
docker compose logs portal --tail 100
docker compose logs -f worker

# Is the portal itself answering?
docker compose exec -T portal php artisan --version
```

If `docker compose ps` shows a container restarting or unhealthy, read its
logs with `docker compose logs <service> --tail 100` before restarting
anything. Restarting first destroys the evidence.

## 1. Port 80/443 conflicts: Apache or Nginx already listening

### Symptom

The installer prints `Caddy: skipped (ports 80/443 busy - use host ports + ngrok)`,
or Caddy fails to start with a bind error, or the dashboard is unreachable on
ports 80/443 even though the containers are up.

### Cause

The installer enables Caddy only when **both** port 80 and port 443 are free
(`install.sh`, `resolve_host_ports()`). A pre-existing Apache or Nginx on the
same VPS occupies one or both ports, so Caddy is skipped and the stack falls
back to host ports. The installer then prints host ports instead, for example
API `:8010`, Dashboard `:3010`, Reverb `:8090`, and picks the next free port
from its fallback lists if the preferred one is busy (portal: 8010, 8001,
8088, 18080; dashboard: 3010, 3001, 3002, 13000; Reverb: 8090, 8080, 8081,
18081).

### Diagnose

```bash
# Who is listening on 80 and 443?
sudo lsof -i :80
sudo lsof -i :443

# If lsof is not installed, use ss instead:
sudo ss -tlnp | grep -E ':(80|443)\b'
```

Note: the installer itself only checks ports with `lsof`. If `lsof` is not
installed on a minimal VPS, `port_in_use()` in `install.sh` cannot see a busy
port and returns "free". Install `lsof` first (`sudo apt-get install -y lsof`)
if the installer and `ss` disagree.

### Fix

Pick one option, do not do both:

**Option A: free ports 80/443 for Caddy (recommended on a dedicated VPS).**

```bash
sudo systemctl stop apache2
sudo systemctl disable apache2
# or, for Nginx:
sudo systemctl stop nginx
sudo systemctl disable nginx
```

Then re-run the installer so it can enable Caddy:

```bash
cd /opt/wp-next-automation
sudo ./install.sh --reconfigure
```

**Option B: keep the existing web server and use host ports.**

Use the host ports the installer printed at the end of the install, for
example `http://127.0.0.1:8010` for the API and `http://127.0.0.1:3010` for
the dashboard, or point an ngrok tunnel at them. Do not edit the Caddyfile
to force Caddy on while Apache or Nginx still holds the ports.

## 2. Firewall (UFW) blocking HTTP/HTTPS

### Symptom

Containers are up and `docker compose ps` looks healthy, but the dashboard
and API do not answer from another machine, while `curl http://127.0.0.1:3010`
on the VPS itself works.

### Cause

The VPS firewall is dropping inbound traffic before it reaches Docker or
Caddy. This is a host-level problem, not a container problem, so container
logs will look normal.

### Fix

```bash
# See what is currently allowed:
sudo ufw status

# Allow web traffic, and SSH first so you do not lock yourself out:
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

If you are using host ports instead of Caddy (see section 1), also allow the
host ports the installer printed, for example 8010 and 3010. If your VPS
provider has its own cloud firewall or security group in addition to UFW,
open 80 and 443 there too; UFW alone will not help if the provider blocks
the traffic first.

## 3. Docker is not running or not installed

### Symptom

`docker: command not found`, `Cannot connect to the Docker daemon`, or the
installer waits and then reports `Docker still not reachable` or
`Could not start Docker daemon`.

### Cause

The installer waits up to 180 seconds for the Docker daemon
(`wait_for_docker_daemon 180` in `install.sh`). If Docker is not installed,
not started, or the current user cannot reach its socket, the wait expires.

### Fix

On Linux, the installer installs Docker Engine and the Compose plugin
automatically when it can. If it still cannot reach the daemon:

```bash
sudo systemctl start docker
sudo systemctl enable docker
docker info
```

On macOS, install and start Docker Desktop, then re-run `./install.sh`
without sudo. On macOS, sudo breaks the Docker Desktop socket: the installer
deliberately runs Docker as the login user on Darwin, so do not run the
installer with `sudo` there. On Linux the opposite applies: run as root
(`sudo ./install.sh`), because the installer exits if it is not root.

## 4. The installer will not run: sudo, TTY, or piped bash

### Symptom

`On Linux, run as root: sudo ./install.sh`, or `Interactive install requires
a TTY`, or the wizard never prompts for input.

### Cause

Three separate rules in `install.sh`:

- On Linux, the installer must run as root.
- The interactive wizard needs a terminal (`[ ! -t 0 ]` check).
- Piping the installer straight into bash (`curl ... | bash`) is not
  supported, because there is no TTY left for the wizard.

### Fix

```bash
# Download first, then run it as a file. Do not pipe it into bash.
curl -fsSL https://raw.githubusercontent.com/boom-devs/wp-next-automation/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

For a non-interactive install, use an env file instead of a TTY:

```bash
sudo ./install.sh --env-file=/path/to/.env
```

See [.env.template](../.env.template) for the required values
(`APP_URL`, `FRONTEND_URL`, `ADMIN_EMAIL`, `ADMIN_PASSWORD` are required;
`APP_KEY`, `JWT_SECRET`, `DB_PASSWORD`, and the Reverb keys must be set for
`--env-file` installs).

## 5. Dashboard will not open, or login fails

### Symptom

The browser shows a connection error, a DNS error, or the login form rejects
the superadmin email and password you set in the wizard.

### Cause

Usually one of three things: DNS does not point at the VPS, the URLs in
`.env` do not match the URLs you are opening, or the portal container is not
healthy yet. The installer waits up to 180 seconds for portal health
(`php artisan --version` in a loop) before running migrations and seeding the
superadmin (`AdminSeeder`), so a login tried too early can also fail.

### Fix

1. Check DNS: `APP_URL` and `FRONTEND_URL` must resolve to the VPS public IP.
   For local testing, use the host ports or an ngrok tunnel instead of a
   production domain.
2. Check the containers: `docker compose ps` should show `portal` healthy.
   The portal healthcheck is `curl -fsS http://127.0.0.1/up` inside the
   container, with a 60 second start period and up to 20 retries.
3. Check the portal logs: `docker compose logs portal --tail 100`.
4. If the containers are healthy but login still fails, confirm you are
   using the superadmin email and password from the wizard, and that the
   seed ran. Re-running the installer with `--reconfigure` overwrites
   `.env`, so back up `.env` first (see section 8).

## 6. Coolify API connectivity fails

### Symptom

**Admin > Integrations > Coolify > Test Coolify** fails, or site
provisioning never starts, even though Coolify itself is reachable in a
browser.

### Cause

The most common causes, in order, are: the API URL field contains a
`/api/v1` suffix (the UI field must be the base host only, for example
`https://your-coolify-host`), the token is wrong or lacks scope, or a UUID
was copied from the wrong place. Coolify, GitHub, and Stripe are configured
after login in **Admin > Integrations**; the wizard does not configure them.

### Fix

1. In the dashboard, set the Coolify API URL to the base host with **no**
   `/api/v1` suffix.
2. Create a fresh token in Coolify under **Keys & Tokens**, paste it, and
   click **Save** before clicking **Test Coolify**. Testing before saving
   tests the old values.
3. Check the UUIDs: Server UUID from the Coolify server URL, Project UUID
   from the Coolify project URL, GitHub App UUID from Coolify **Sources**,
   Environment usually `production`.
4. Test the token directly from the VPS with curl, against the version
   endpoint. This is the cheapest authenticated probe in the Coolify v4 API:

```bash
curl -fsS -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  -H "Accept: application/json" \
  "$COOLIFY_URL/api/v1/version"
```

A working token returns the Coolify version, for example `"v4.0.0"`.
`{"message": "Invalid token."}` means the token is wrong or revoked, so
create a new one in Coolify and save it again. A connection timeout
(`curl: (28)`) means a firewall or DNS problem between this VPS and the
Coolify host, not a token problem; see section 2.

Do not paste a real token into a GitHub issue or a chat log. Tokens are
shown only once when created, and they are stored encrypted in the
platform settings database.

## 7. GitHub integration fails: org 404, PAT scope, or connector 403

### Symptom

**Test GitHub** fails, repo creation fails with a 404, or the connector
plugin download fails with a 403.

### Cause

- **Org 404:** the Organization field is not a real org slug or your
  username. Use the exact slug, or your personal username for personal repos.
- **PAT scope:** a Personal Access Token used for repo creation needs the
  `repo` scope. A token without it can authenticate but cannot create repos.
- **OAuth callback:** a GitHub OAuth App must use the callback shown on the
  Integrations page, `{APP_URL}/github/callback`, with the dashboard URL as
  the homepage.
- **Connector 403:** the connector plugin repo (`AWN_PLUGIN_GITHUB_REPO`,
  default `boom-devs/wp-next-connector`) is private, or the configured token
  cannot read it. The installer does not push the plugin into your GitHub.

### Fix

1. Save the GitHub settings first, then click **Test GitHub**.
2. For a public setup, point the connector plugin repo at a public repo so
   any self-hoster can download it. For a private fork, use a token that can
   read that fork and set `AWN_PLUGIN_GITHUB_REPO` to `owner/repo` and
   `AWN_PLUGIN_GITHUB_REF` to `main`.
3. If auto-install still fails, install the connector ZIP manually in
   WordPress Admin (**Plugins > Add New Plugin > Upload Plugin**) and pair
   it with the site sync token. See [CONNECTOR_PLUGIN.md](./CONNECTOR_PLUGIN.md).

## 8. Database reset: `.env` password no longer matches the MySQL volume

### Symptom

Migrations fail with `Access denied` or MySQL error `1045`, usually after a
re-install or a `--reconfigure` run that regenerated secrets.

### Cause

MySQL only applies `MYSQL_PASSWORD` the first time the `mysql_data` volume
is initialised. On later runs the installer reuses the existing
`DB_PASSWORD` when the volume already exists, so a re-run does not break
auth. But if `.env` was regenerated or hand-edited so `DB_PASSWORD` no
longer matches the password stored in the volume, the portal cannot log in
to MySQL. The installer detects this (`reset_mysql_volume_if_auth_fails()` in
`install.sh`): when `php artisan migrate:status` reports `Access denied` or
`1045`, it stops the stack, removes the `mysql_data` volume, and recreates
it so the `.env` password applies again.

### Fix

**Warning: resetting the volume deletes the control plane database.** That
includes platform settings, tenant records, and the superadmin account. The
provisioned customer WordPress sites live in Coolify, not in this database,
but back up first anyway.

```bash
cd /opt/wp-next-automation

# 1. Back up the database before touching the volume:
docker compose exec -T db mysqldump -u wpnext -p"$DB_PASSWORD" wp_next_automation > backup.sql

# 2. Back up .env, which --reconfigure overwrites:
cp .env .env.backup-$(date +%Y%m%d)

# 3. If the installer has not already reset the volume, do it by hand:
docker compose stop
docker compose rm -f db
docker volume ls | grep mysql_data
docker volume rm -f <volume-name-from-the-previous-command>

# 4. Bring the database back and check it accepts the .env password:
docker compose up -d db
docker compose exec -T db mysql -uwpnext -p"$DB_PASSWORD" -e "SELECT 1"
docker compose up -d
```

If the installer already reset the volume for you, do **not** reset it a
second time. Instead, restore `.env` from your backup so the password in
`.env` is the one the fresh volume was created with, then restart the stack.
Never delete the volume to "fix" a typo in `.env` without a backup: fix the
typo in `.env` first and restart, and only reset the volume when the error
is genuinely `Access denied` / `1045` after a password drift.

## 9. WordPress sync fails: connector plugin problems

These are the connector failures documented in
[CONNECTOR_PLUGIN.md](./CONNECTOR_PLUGIN.md). The short version:

| Symptom | Cause | Fix |
|---|---|---|
| `404 Not Found` on `/wp-json/awn/v1/sync` | WordPress permalinks are set to Plain | In WP Admin, go to **Settings > Permalinks** and select **Post name** (`/%postname%/`) |
| `401 Unauthorized` during sync | The site sync token does not match the portal record | Copy the sync token from the dashboard (**Sites**, `awn_api_token`) and re-save it in the plugin settings (**Settings > WP Next Connector**), with the Control Plane API URL (`APP_URL`) |
| `cURL 28: Connection timed out` | Firewall or Docker network blocking container-to-container calls | Make sure the WordPress container can resolve and reach `APP_URL` |
| Cloudflare `403 Forbidden` on webhook | Cloudflare WAF / Bot Fight Mode blocking automated POST requests | Add a Cloudflare WAF skip rule for `/wp-json/awn/*` and `/api/stripe/webhook` |

If the connector was never installed, the portal cannot sync at all. Check
the plugin repo access first (section 7), then install the ZIP manually if
needed.

## 10. Provisioning works, but Coolify never rebuilds the Next.js app

### Symptom

Content is published in WordPress, the portal pushes to GitHub, but the
Next.js app in Coolify does not rebuild.

### Cause

The portal is supposed to POST `/deploy` to Coolify after the GitHub push.
If the queue worker is down, stuck, or erroring, the push happens but the
deploy trigger never fires. The worker runs
`php artisan queue:work --queue=bulk-finalize,bulk-chunks,bulk-content,provisioning,default --timeout=900 --tries=3`
in `docker-compose.yml`, so a failed job is retried 3 times and then stops.

### Fix

```bash
cd /opt/wp-next-automation

# Check the worker, not just the portal:
docker compose ps worker
docker compose logs -f worker

# Restart the worker and the portal:
docker compose restart worker portal
```

If the worker logs show a Coolify error, go back to section 6 and re-test
the Coolify connection. As a fallback, trigger a manual **Deploy** in
Coolify for the Next.js app, then watch the worker logs on the next publish.

## 11. No emails: no WordPress password email, no reset email

### Symptom

Sites are created but the WordPress login details never arrive by email.

### Cause

The default mailer is `log`, which writes mail to the logs and sends
nothing. Mail is configured after login in **Admin > Integrations > Mail**,
and the installer does not configure SMTP.

### Fix

Set Mailer to `smtp` with your host, port, username, password, and from
address, click **Save & send test email**, and check the portal logs if the
test fails. Until SMTP works, copy the WordPress credentials from the
dashboard instead of waiting for the email.

## 12. Slow install, out of memory, or containers keep restarting

### Symptom

The install is very slow, a container is killed, or `docker compose ps`
shows containers restarting in a loop.

### Cause

The installer warns when the VPS has less than about 2 GB of RAM
(`preflight()` in `install.sh`); the install guide recommends 2 GB minimum
and 4 GB or more. The stack runs a Laravel portal, queue workers, a
scheduler, a Next.js dashboard, Reverb, MySQL 8.0, Redis, and optionally
Caddy on one VPS, so a 1 GB VPS will struggle.

### Fix

- Use a VPS with at least 2 GB RAM, 4 GB recommended.
- Check which container is restarting and read its logs before changing
  anything: `docker compose logs <service> --tail 100`.
- Do not lower MySQL or PHP memory limits to force the stack onto a small
  VPS; upgrade the VPS instead.

## 13. `make lint` fails

### Symptom

`make lint` exits non-zero after a change.

### Cause

`make lint` runs two checks (see `Makefile` and `AGENTS.md`):

1. `shellcheck -x install.sh lib/wizard.sh` - zero warnings allowed.
2. `docker compose -f docker-compose.yml config` and the same check with
   `docker-compose.dev.yml` - the Compose files must parse cleanly.

A documentation-only change, like this guide, does not touch either check,
but run `make lint` before every PR anyway, as the contribution workflow
requires.

### Fix

```bash
make lint
```

Read the first error ShellCheck or Compose reports and fix that line; do not
silence the check. On macOS, run it without sudo. If `docker compose`
itself is missing, see section 3.

## Still stuck?

1. Run the quick diagnostics at the top of this guide and copy the exact
   error message, not a paraphrase.
2. Note your setup: Ubuntu version, VPS provider, RAM, whether Caddy is
   enabled, and whether you used host ports or a domain.
3. Open an issue with the [bug report template](../.github/ISSUE_TEMPLATE/bug_report.yml),
   paste the exact error and the relevant `docker compose logs` output, and
   say which section of this guide you already tried. Do not paste tokens,
   passwords, or the contents of `.env` into an issue.
