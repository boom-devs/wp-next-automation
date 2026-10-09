#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wizard.sh
source "$ROOT_DIR/lib/wizard.sh"

VERSION="${WP_NEXT_VERSION:-1.0.0}"
ENV_FILE_ARG=""
RECONFIGURE=0
NONINTERACTIVE=0
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~${REAL_USER}")"

detect_os() {
  case "$(uname -s)" in
    Linux*) echo linux ;;
    Darwin*) echo macos ;;
    *) echo other ;;
  esac
}

OS_KIND="$(detect_os)"
if [ "$OS_KIND" = "macos" ]; then
  INSTALL_DIR_DEFAULT="${REAL_HOME}/wp-next-automation"
else
  INSTALL_DIR_DEFAULT="/opt/wp-next-automation"
fi

usage() {
  cat <<EOF
WP Next Automation installer v${VERSION}

Usage:
  ./install.sh                  # macOS (Docker Desktop)
  sudo ./install.sh             # Linux VPS
  ./install.sh --env-file=./.env
  ./install.sh --reconfigure

Options:
  --env-file=PATH   Skip interactive wizard; use existing env file
  --reconfigure     Re-run wizard and overwrite .env
  -h, --help        Show help

TTY tip: do not use "curl | bash" for interactive install.
  curl -fsSL <url>/install.sh -o install.sh && chmod +x install.sh && ./install.sh
EOF
}

# On macOS, sudo breaks Docker Desktop socket — always call docker as the login user.
docker_cli() {
  if [ "$OS_KIND" = "macos" ] && [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" -H docker "$@"
  else
    docker "$@"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --env-file=*)
      ENV_FILE_ARG="${arg#*=}"
      NONINTERACTIVE=1
      ;;
    --reconfigure)
      RECONFIGURE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

if [ "$OS_KIND" = "linux" ] && [ "$(id -u)" -ne 0 ]; then
  echo "On Linux, run as root: sudo ./install.sh"
  exit 1
fi

if [ "$NONINTERACTIVE" -eq 0 ] && [ ! -t 0 ]; then
  echo "Interactive install requires a TTY."
  echo "Use: curl -fsSL <url> -o install.sh && chmod +x install.sh && ./install.sh"
  echo "Or:  ./install.sh --env-file=/path/to/.env"
  exit 1
fi

ensure_basics() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y curl ca-certificates
    elif command -v yum >/dev/null 2>&1; then
      yum install -y curl ca-certificates
    else
      echo "Please install curl, then re-run."
      exit 1
    fi
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    echo "Installing openssl..."
    if command -v apt-get >/dev/null 2>&1; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y openssl
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y openssl
    elif command -v yum >/dev/null 2>&1; then
      yum install -y openssl
    else
      echo "Please install openssl, then re-run."
      exit 1
    fi
  fi
}

wait_for_docker_daemon() {
  local seconds="${1:-120}"
  local i
  local steps=$((seconds / 2))
  echo "Waiting for Docker to become ready..."
  for i in $(seq 1 "$steps"); do
    if docker_cli info >/dev/null 2>&1; then
      echo "Docker is ready."
      return 0
    fi
    # progress every ~10s
    if [ $((i % 5)) -eq 0 ]; then
      echo "  still waiting... ($((i * 2))s)"
    fi
    sleep 2
  done
  return 1
}

# macOS popup: OK starts Docker Desktop and continues this same install session.
macos_prompt_start_docker() {
  local result
  result="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
try
  display dialog "Docker Desktop is installed but not running.

Click OK to start Docker Desktop.
Installation will continue automatically — you do not need to re-run the command." buttons {"Cancel", "OK"} default button "OK" with title "WP Next Automation Installer" with icon caution
  return "ok"
on error
  return "cancel"
end try
APPLESCRIPT
)"
  [ "$result" = "ok" ]
}

ensure_docker_running() {
  if docker_cli info >/dev/null 2>&1; then
    return 0
  fi

  echo "Docker is installed but not running."

  if [ "$OS_KIND" = "macos" ]; then
    if [ "$NONINTERACTIVE" -eq 1 ]; then
      open -a Docker 2>/dev/null || true
    else
      if command -v osascript >/dev/null 2>&1; then
        if ! macos_prompt_start_docker; then
          echo "Cancelled. Start Docker Desktop, then re-run ./install.sh"
          exit 1
        fi
      elif ! ask_yes_no "Start Docker Desktop now and continue?" "y"; then
        exit 1
      fi
      open -a Docker 2>/dev/null || true
    fi

    if ! wait_for_docker_daemon 180; then
      if [ "$NONINTERACTIVE" -eq 0 ] && command -v osascript >/dev/null 2>&1; then
        osascript -e 'display dialog "Docker Desktop is still starting or failed to start.\n\nClick OK to keep waiting, or Cancel to abort." buttons {"Cancel", "OK"} default button "OK" with title "WP Next Automation Installer"' >/dev/null 2>&1 || exit 1
        open -a Docker 2>/dev/null || true
        wait_for_docker_daemon 120 || {
          echo "Docker still not reachable. Open Docker Desktop manually, then re-run."
          exit 1
        }
      else
        echo "Docker still not reachable."
        exit 1
      fi
    fi
    return 0
  fi

  # Linux
  if [ "$NONINTERACTIVE" -eq 1 ] || ask_yes_no "Start Docker service now and continue?" "y"; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable --now docker || true
    elif command -v service >/dev/null 2>&1; then
      service docker start || true
    fi
    wait_for_docker_daemon 60 || {
      echo "Could not start Docker daemon."
      exit 1
    }
  else
    exit 1
  fi
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    if [ "$OS_KIND" = "macos" ] || [ "$OS_KIND" = "other" ]; then
      if [ "$OS_KIND" = "macos" ] && command -v osascript >/dev/null 2>&1 && [ "$NONINTERACTIVE" -eq 0 ]; then
        osascript -e 'display dialog "Docker Desktop is not installed.\n\nClick OK to open the download page, install it, then run ./install.sh again." buttons {"OK"} default button "OK" with title "WP Next Automation Installer"' >/dev/null 2>&1 || true
        open "https://www.docker.com/products/docker-desktop/" 2>/dev/null || true
      fi
      echo "Install Docker Desktop, then run ./install.sh again."
      exit 1
    fi

    echo "Docker not found — installing Docker Engine + Compose plugin..."
    if [ "$NONINTERACTIVE" -eq 1 ] || ask_yes_no "Install Docker now via get.docker.com?" "y"; then
      curl -fsSL https://get.docker.com | sh
    else
      echo "Docker is required. Aborting."
      exit 1
    fi

    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable --now docker || true
    elif command -v service >/dev/null 2>&1; then
      service docker start || true
    fi
  fi

  if ! docker_cli compose version >/dev/null 2>&1; then
    if [ "$OS_KIND" = "linux" ]; then
      echo "Installing docker-compose-plugin..."
      if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin || true
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y docker-compose-plugin || true
      fi
    fi
  fi

  if ! docker_cli compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 is missing."
    exit 1
  fi

  ensure_docker_running

  echo "Docker + Compose ready."
  docker_cli --version
  docker_cli compose version
}

preflight() {
  ensure_basics
  ensure_docker

  local mem_kb
  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  if [ "${mem_kb:-0}" -gt 0 ] && [ "$mem_kb" -lt 1800000 ]; then
    echo "WARNING: less than ~2GB RAM detected. Install may be slow or fail."
  fi
}

# Prefer building from sibling source trees (local/OSS). GHCR images are optional.
first_existing_dir() {
  local d
  for d in "$@"; do
    if [ -d "$d" ] && [ -f "$d/Dockerfile" ]; then
      (cd "$d" && pwd)
      return 0
    fi
  done
  return 1
}

resolve_image_sources() {
  PORTAL_BUILD_CONTEXT="$(first_existing_dir \
    "${PORTAL_BUILD_CONTEXT:-}" \
    "$ROOT_DIR/../frontis-cloud-portal" \
    "$ROOT_DIR/apps/portal" \
    "$ROOT_DIR/frontis-cloud-portal" \
    "${REAL_HOME}/Desktop/frontis-cloud-portal" \
    || true)"
  DASHBOARD_BUILD_CONTEXT="$(first_existing_dir \
    "${DASHBOARD_BUILD_CONTEXT:-}" \
    "$ROOT_DIR/../wp-next-automation-dashbaord" \
    "$ROOT_DIR/../wp-next-automation-dashboard" \
    "$ROOT_DIR/apps/dashboard" \
    "$ROOT_DIR/wp-next-automation-dashbaord" \
    "${REAL_HOME}/Desktop/wp-next-automation-dashbaord" \
    "${REAL_HOME}/Desktop/wp-next-automation-dashboard" \
    || true)"

  if [ -n "${PORTAL_BUILD_CONTEXT:-}" ]; then
    # Prefer local build over unpublished/private GHCR tags.
    if [ -z "${PORTAL_IMAGE:-}" ] || [[ "$PORTAL_IMAGE" == ghcr.io/* ]]; then
      PORTAL_IMAGE="wp-next-automation-portal:local"
    fi
    echo "Portal source:    $PORTAL_BUILD_CONTEXT (local build)"
  else
    PORTAL_IMAGE="${PORTAL_IMAGE:-ghcr.io/boom-devs/wp-next-automation-backend:${VERSION}}"
    PORTAL_BUILD_CONTEXT="../frontis-cloud-portal"
    echo "Portal image:     $PORTAL_IMAGE (no local source found)"
  fi

  if [ -n "${DASHBOARD_BUILD_CONTEXT:-}" ]; then
    if [ -z "${DASHBOARD_IMAGE:-}" ] || [[ "$DASHBOARD_IMAGE" == ghcr.io/* ]]; then
      DASHBOARD_IMAGE="wp-next-automation-dashboard:local"
    fi
    echo "Dashboard source: $DASHBOARD_BUILD_CONTEXT (local build)"
  else
    DASHBOARD_IMAGE="${DASHBOARD_IMAGE:-ghcr.io/boom-devs/wp-next-automation-dashboard:${VERSION}}"
    DASHBOARD_BUILD_CONTEXT="../wp-next-automation-dashbaord"
    echo "Dashboard image:  $DASHBOARD_IMAGE (no local source found)"
  fi
}

write_env_file() {
  local dest="$1"
  resolve_image_sources
  cat >"$dest" <<EOF
# Generated by WP Next Automation installer $(date -u +%Y-%m-%dT%H:%MZ)
APP_NAME=$(escape_env_value "$APP_NAME")
APP_ENV=production
APP_KEY=base64:${APP_KEY_B64}
APP_DEBUG=false
APP_URL=$(escape_env_value "$APP_URL")
FRONTEND_URL=$(escape_env_value "$FRONTEND_URL")
FRONTEND_APP_URL=$(escape_env_value "$FRONTEND_URL")
CORS_ALLOWED_ORIGINS=$(escape_env_value "$FRONTEND_URL")

ADMIN_EMAIL=$(escape_env_value "$ADMIN_EMAIL")
ADMIN_PASSWORD=$(escape_env_value "$ADMIN_PASSWORD")

LOG_CHANNEL=stderr
LOG_LEVEL=info

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=wp_next_automation
DB_USERNAME=wpnext
DB_PASSWORD=$(escape_env_value "$DB_PASSWORD")

CACHE_STORE=redis
QUEUE_CONNECTION=database
SESSION_DRIVER=database
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME=$(escape_env_value "$APP_NAME")

JWT_SECRET=$(escape_env_value "$JWT_SECRET")
JWT_ALGO=HS256

BROADCAST_CONNECTION=reverb
REVERB_APP_ID=$(escape_env_value "$REVERB_APP_ID")
REVERB_APP_KEY=$(escape_env_value "$REVERB_APP_KEY")
REVERB_APP_SECRET=$(escape_env_value "$REVERB_APP_SECRET")
REVERB_HOST=reverb
REVERB_PORT=8080
REVERB_SCHEME=http

NEXT_PUBLIC_BACKEND_APP_URL=$(escape_env_value "$APP_URL")
NEXT_PUBLIC_REVERB_APP_KEY=$(escape_env_value "$REVERB_APP_KEY")
NEXT_PUBLIC_REVERB_HOST=$(escape_env_value "$REVERB_PUBLIC_HOST")
NEXT_PUBLIC_REVERB_PORT=$(escape_env_value "$REVERB_PUBLIC_PORT")
NEXT_PUBLIC_REVERB_SCHEME=$(escape_env_value "$REVERB_PUBLIC_SCHEME")

# Coolify / GitHub / Stripe are configured after login in Admin → Integrations
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GITHUB_REDIRECT_URI=$(escape_env_value "${APP_URL}/github/callback")
GITHUB_ADMIN_TOKEN=
GITHUB_ORGANIZATION=
GITHUB_NEW_REPO_PRIVATE=true

COOLIFY_API_URL=
COOLIFY_API_TOKEN=
COOLIFY_PROJECT_UUID=
COOLIFY_ENVIRONMENT_NAME=production
COOLIFY_SERVER_UUID=
COOLIFY_GITHUB_APP_UUID=
COOLIFY_METRICS_HOST=
COOLIFY_SSH_USE_API_KEY=true
COOLIFY_SENTINEL_ENABLED=false

AWN_PLUGIN_GITHUB_REPO=
AWN_PLUGIN_GITHUB_REF=main

STRIPE_KEY=
STRIPE_SECRET=
STRIPE_WEBHOOK_SECRET=
CASHIER_CURRENCY=usd
STRIPE_SYNC_ENABLED=false
STRIPE_MODE=test

N8N_WP_NEXT_ENABLED=false

RUN_MIGRATIONS=true
SKIP_DB_WAIT=false

PORTAL_IMAGE=$(escape_env_value "$PORTAL_IMAGE")
DASHBOARD_IMAGE=$(escape_env_value "$DASHBOARD_IMAGE")
PORTAL_BUILD_CONTEXT=$(escape_env_value "$PORTAL_BUILD_CONTEXT")
DASHBOARD_BUILD_CONTEXT=$(escape_env_value "$DASHBOARD_BUILD_CONTEXT")

# Host ports for local/ngrok (Caddy is optional via COMPOSE_PROFILES=caddy)
PORTAL_HOST_PORT=${PORTAL_HOST_PORT:-8001}
DASHBOARD_HOST_PORT=${DASHBOARD_HOST_PORT:-3001}
REVERB_HOST_PORT=${REVERB_HOST_PORT:-8080}
COMPOSE_PROFILES=${COMPOSE_PROFILES:-}
EOF
  chmod 600 "$dest"
}

run_wizard() {
  echo
  echo "=== WP Next Automation installer v${VERSION} ==="
  echo "Step 1/3 — Domains & superadmin (Coolify / GitHub / Stripe are set in Admin → Integrations after login)"
  echo

  INSTALL_DIR="$(ask "Install directory" "$INSTALL_DIR_DEFAULT")"
  APP_NAME="$(ask "App name" "WP Next Automation")"
  while true; do
    APP_URL="$(ask_required "API URL (APP_URL)" "https://api.example.com")"
    validate_url "$APP_URL" && break
    echo "  Enter a valid http(s) URL."
  done
  while true; do
    FRONTEND_URL="$(ask_required "Dashboard URL (FRONTEND_URL)" "https://app.example.com")"
    validate_url "$FRONTEND_URL" && break
    echo "  Enter a valid http(s) URL."
  done
  while true; do
    ADMIN_EMAIL="$(ask_required "Superadmin email" "admin@example.com")"
    validate_email "$ADMIN_EMAIL" && break
    echo "  Enter a valid email."
  done
  ADMIN_PASSWORD="$(ask_secret "Superadmin password")"

  echo
  echo "Step 2/3 — Generating secrets..."
  APP_KEY_B64="$(gen_base64)"
  JWT_SECRET="$(gen_hex 32)"
  # MySQL only applies MYSQL_PASSWORD on first volume init — reuse existing password
  # when the data volume already exists so re-runs don't break auth.
  DB_PASSWORD="$(gen_hex 16)"
  if [ -f "$INSTALL_DIR/.env" ]; then
    local existing_db_pw
    existing_db_pw="$(grep -E '^DB_PASSWORD=' "$INSTALL_DIR/.env" | head -1 | cut -d= -f2- || true)"
    if [ -n "$existing_db_pw" ] && docker_cli volume inspect wp-next-automation_mysql_data >/dev/null 2>&1; then
      DB_PASSWORD="$existing_db_pw"
      echo "  Reusing existing DB_PASSWORD (MySQL volume already initialized)"
    fi
  fi
  REVERB_APP_ID="$(gen_hex 4)"
  REVERB_APP_KEY="$(gen_hex 10)"
  REVERB_APP_SECRET="$(gen_hex 20)"

  REVERB_PUBLIC_HOST="$(printf '%s' "$APP_URL" | sed -E 's#https?://##; s#/.*##')"
  if [[ "$APP_URL" == https://* ]]; then
    REVERB_PUBLIC_SCHEME=https
    REVERB_PUBLIC_PORT=443
  else
    REVERB_PUBLIC_SCHEME=http
    REVERB_PUBLIC_PORT=80
  fi

  echo
  echo "=== Summary ==="
  echo "  Install dir:     $INSTALL_DIR"
  echo "  APP_URL:         $APP_URL"
  echo "  FRONTEND_URL:    $FRONTEND_URL"
  echo "  Superadmin:      $ADMIN_EMAIL"
  echo "  Integrations:    configure Coolify, GitHub, Stripe after login"
  echo
  if ! ask_yes_no "Step 3/3 — Proceed with Docker install?" "y"; then
    echo "Aborted."
    exit 1
  fi
}

copy_stack_files() {
  mkdir -p "$INSTALL_DIR"
  cp -f "$ROOT_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml"

  local api_host dash_host
  api_host="$(printf '%s' "${APP_URL:-api.example.com}" | sed -E 's#https?://##; s#/.*##')"
  dash_host="$(printf '%s' "${FRONTEND_URL:-app.example.com}" | sed -E 's#https?://##; s#/.*##')"
  cat >"$INSTALL_DIR/Caddyfile" <<EOF
${api_host} {
	reverse_proxy portal:80
}

${dash_host} {
	reverse_proxy dashboard:3000
}
EOF
}

port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  return 1
}

pick_free_port() {
  local preferred="$1"
  shift
  local p
  if ! port_in_use "$preferred"; then
    echo "$preferred"
    return 0
  fi
  for p in "$@"; do
    if ! port_in_use "$p"; then
      echo "$p"
      return 0
    fi
  done
  echo "$preferred"
}

resolve_host_ports() {
  local want_portal="${PORTAL_HOST_PORT:-8010}"
  local want_dash="${DASHBOARD_HOST_PORT:-3010}"
  local want_reverb="${REVERB_HOST_PORT:-8090}"

  PORTAL_HOST_PORT="$(pick_free_port "$want_portal" 8010 8001 8088 18080)"
  DASHBOARD_HOST_PORT="$(pick_free_port "$want_dash" 3010 3001 3002 13000)"
  REVERB_HOST_PORT="$(pick_free_port "$want_reverb" 8090 8080 8081 18081)"

  # Auto-enable Caddy when 80/443 are free (typical VPS). Skip on Mac/Herd.
  if ! port_in_use 80 && ! port_in_use 443; then
    COMPOSE_PROFILES=caddy
    echo "Caddy:            enabled (ports 80/443 free)"
  else
    COMPOSE_PROFILES=""
    echo "Caddy:            skipped (ports 80/443 busy — use host ports + ngrok)"
  fi

  echo "Host ports:       API :${PORTAL_HOST_PORT}  Dashboard :${DASHBOARD_HOST_PORT}  Reverb :${REVERB_HOST_PORT}"
}

upsert_env_kv() {
  local envf="$1" key="$2" val="$3" tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$val" '
    BEGIN { done=0 }
    $0 ~ ("^" k "=") { print k "=" v; done=1; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$envf" >"$tmp"
  mv "$tmp" "$envf"
}

ensure_env_build_contexts() {
  local envf="$INSTALL_DIR/.env"
  [ -f "$envf" ] || return 0

  # Re-resolve when .env still points at GHCR / relative sibling paths that
  # don't exist from the install dir (common after first local Mac attempt).
  resolve_image_sources
  resolve_host_ports

  upsert_env_kv "$envf" PORTAL_IMAGE "$PORTAL_IMAGE"
  upsert_env_kv "$envf" DASHBOARD_IMAGE "$DASHBOARD_IMAGE"
  upsert_env_kv "$envf" PORTAL_BUILD_CONTEXT "$PORTAL_BUILD_CONTEXT"
  upsert_env_kv "$envf" DASHBOARD_BUILD_CONTEXT "$DASHBOARD_BUILD_CONTEXT"
  upsert_env_kv "$envf" PORTAL_HOST_PORT "$PORTAL_HOST_PORT"
  upsert_env_kv "$envf" DASHBOARD_HOST_PORT "$DASHBOARD_HOST_PORT"
  upsert_env_kv "$envf" REVERB_HOST_PORT "$REVERB_HOST_PORT"
  upsert_env_kv "$envf" COMPOSE_PROFILES "${COMPOSE_PROFILES:-}"
  chmod 600 "$envf"
}

start_stack() {
  cd "$INSTALL_DIR"
  if [ "$OS_KIND" = "macos" ] && [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER" "$INSTALL_DIR" || true
  fi

  # If Docker was stopped after the wizard, start it here and continue (no re-prompt).
  ensure_docker_running
  ensure_env_build_contexts

  echo "Starting Docker Compose stack..."
  # Pull public deps. App images may be local builds only.
  if [[ "${PORTAL_IMAGE:-}" == ghcr.io/* ]] || [[ "${DASHBOARD_IMAGE:-}" == ghcr.io/* ]]; then
    docker_cli compose pull || true
  else
    docker_cli compose pull db redis || true
  fi
  docker_cli compose up -d --build
  # Remove stale caddy container if profile is off and ports were conflicting.
  if [ -z "${COMPOSE_PROFILES:-}" ]; then
    docker_cli compose rm -f caddy >/dev/null 2>&1 || true
  fi
  echo "Waiting for portal health..."
  for i in $(seq 1 60); do
    if docker_cli compose exec -T portal php artisan --version >/dev/null 2>&1; then
      break
    fi
    sleep 3
  done

  # If .env DB_PASSWORD drifted from the MySQL volume (re-run regenerated secrets),
  # wipe the volume once and recreate so MYSQL_* env vars apply again.
  reset_mysql_volume_if_auth_fails

  echo "Running migrations..."
  docker_cli compose exec -T portal php artisan migrate --force --no-interaction
  echo "Seeding superadmin..."
  docker_cli compose exec -T portal php artisan db:seed --class=AdminSeeder --force --no-interaction
}

reset_mysql_volume_if_auth_fails() {
  local out pw vol i st
  out="$(docker_cli compose exec -T portal php artisan migrate:status --no-interaction 2>&1 || true)"
  if ! printf '%s' "$out" | grep -qiE 'Access denied|1045'; then
    return 0
  fi

  pw="${DB_PASSWORD:-}"
  if [ -z "$pw" ] && [ -f "$INSTALL_DIR/.env" ]; then
    pw="$(grep -E '^DB_PASSWORD=' "$INSTALL_DIR/.env" | head -1 | cut -d= -f2- || true)"
  fi

  echo "MySQL auth mismatch detected (.env DB_PASSWORD != mysql volume)."
  echo "Resetting mysql_data so MYSQL_PASSWORD from .env is applied..."
  docker_cli compose stop || true
  docker_cli compose rm -f db || true
  for vol in $(docker_cli volume ls -q | grep -E 'wp-next-automation.*mysql_data' || true); do
    docker_cli volume rm -f "$vol" >/dev/null 2>&1 || true
  done

  docker_cli compose up -d db
  echo "Waiting for fresh MySQL..."
  for i in $(seq 1 45); do
    st="$(docker_cli compose ps db --format '{{.Status}}' 2>/dev/null || true)"
    if printf '%s' "$st" | grep -qi healthy; then
      break
    fi
    sleep 2
  done

  if [ -n "$pw" ]; then
    if ! docker_cli compose exec -T db mysql -uwpnext -p"$pw" -e "SELECT 1" >/dev/null 2>&1; then
      echo "ERROR: MySQL still rejecting DB_PASSWORD after volume reset."
      exit 1
    fi
  fi

  docker_cli compose up -d
  for i in $(seq 1 40); do
    if docker_cli compose exec -T portal php artisan --version >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
}

print_done() {
  local portal_port="${PORTAL_HOST_PORT:-8001}"
  local dash_port="${DASHBOARD_HOST_PORT:-3001}"
  local reverb_port="${REVERB_HOST_PORT:-8080}"
  cat <<EOF

=== Install complete ===
Dashboard:  $FRONTEND_URL
API:        $APP_URL
Admin:      $ADMIN_EMAIL
Password:   (the one you entered)

Local ports (ngrok / direct):
  API        http://127.0.0.1:${portal_port}
  Dashboard  http://127.0.0.1:${dash_port}
  Reverb     http://127.0.0.1:${reverb_port}

Next steps:
  1. Point DNS (VPS) or ngrok tunnels (local) at the ports above.
  2. Login as superadmin → Admin → Integrations.
  3. Configure Coolify, GitHub, and Stripe; sync subscription plans.
  4. Share /pricing so customers can buy and create sites.

Upgrade later:
  cd $INSTALL_DIR && $ROOT_DIR/install.sh --env-file=$INSTALL_DIR/.env

Files: $INSTALL_DIR
EOF
}

main() {
  preflight

  if [ "$NONINTERACTIVE" -eq 1 ]; then
    [ -f "$ENV_FILE_ARG" ] || { echo "Env file not found: $ENV_FILE_ARG"; exit 1; }
    # shellcheck disable=SC1090
    set -a; source "$ENV_FILE_ARG"; set +a
    INSTALL_DIR="${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}"
    APP_URL="${APP_URL:?APP_URL required}"
    FRONTEND_URL="${FRONTEND_URL:?FRONTEND_URL required}"
    ADMIN_EMAIL="${ADMIN_EMAIL:?ADMIN_EMAIL required}"
    copy_stack_files
    cp -f "$ENV_FILE_ARG" "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
    start_stack
    print_done
    exit 0
  fi

  if [ -f "${INSTALL_DIR_DEFAULT}/.env" ] && [ "$RECONFIGURE" -eq 0 ]; then
    echo "Existing install detected at $INSTALL_DIR_DEFAULT"
    if ask_yes_no "Re-run wizard and overwrite .env?" "n"; then
      RECONFIGURE=1
    else
      INSTALL_DIR="$INSTALL_DIR_DEFAULT"
      # shellcheck disable=SC1091
      set -a; source "$INSTALL_DIR/.env"; set +a
      copy_stack_files
      start_stack
      print_done
      exit 0
    fi
  fi

  run_wizard
  copy_stack_files
  write_env_file "$INSTALL_DIR/.env"
  start_stack
  print_done
}

main "$@"
