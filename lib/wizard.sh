#!/usr/bin/env bash
# Interactive prompt helpers for install.sh

ask() {
  local label="$1"
  local default="${2:-}"
  local value=""
  if [ -n "$default" ]; then
    read -r -p "$label [$default]: " value || true
    value="${value:-$default}"
  else
    read -r -p "$label: " value || true
  fi
  printf '%s' "$value"
}

ask_required() {
  local label="$1"
  local default="${2:-}"
  local value=""
  while true; do
    value="$(ask "$label" "$default")"
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return 0
    fi
    echo "  This value is required."
  done
}

ask_secret() {
  local label="$1"
  local value=""
  local confirm=""
  while true; do
    read -r -s -p "$label: " value || true
    echo
    if [ -z "$value" ]; then
      echo "  Secret cannot be empty."
      continue
    fi
    if [ "${#value}" -lt 8 ]; then
      echo "  Secret must be at least 8 characters."
      continue
    fi
    read -r -s -p "Confirm $label: " confirm || true
    echo
    if [ "$value" = "$confirm" ]; then
      printf '%s' "$value"
      return 0
    fi
    echo "  Values did not match. Try again."
  done
}

ask_secret_optional() {
  local label="$1"
  local value=""
  read -r -s -p "$label (Enter to skip): " value || true
  echo
  printf '%s' "$value"
}

ask_yes_no() {
  local label="$1"
  local default="${2:-n}"
  local hint="y/N"
  [ "$default" = "y" ] && hint="Y/n"
  local value=""
  read -r -p "$label [$hint]: " value || true
  value="$(printf '%s' "${value:-$default}" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

validate_url() {
  local url="$1"
  [[ "$url" =~ ^https?://[^[:space:]]+$ ]]
}

validate_email() {
  local email="$1"
  [[ "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
}

gen_hex() {
  local bytes="${1:-32}"
  openssl rand -hex "$bytes" 2>/dev/null || head -c "$bytes" /dev/urandom | xxd -p -c 256
}

gen_base64() {
  openssl rand -base64 32 2>/dev/null | tr -d '\n'
}

escape_env_value() {
  # Always single-quote for dotenv (safe for # " $ ` spaces).
  # Embed a single quote as: '"'"'
  local v="$1"
  v="${v//\'/\'\\\'\'}"
  printf "'%s'" "$v"
}
