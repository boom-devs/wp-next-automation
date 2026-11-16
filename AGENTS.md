# WP Next Automation — AI Agent & Developer Architecture Guide

Welcome to **WP Next Automation**, the open-source control plane for headless WordPress and Next.js sites on Coolify.

This document serves as the architectural reference and operating standard for AI coding agents (Antigravity, Cursor, Claude Code, GitHub Copilot) and human maintainers contributing to this repository.

---

## 🏗️ Repository Architecture

```text
wp-next-automation/
├── install.sh                  # Interactive/non-interactive CLI installer & validator
├── Makefile                    # Developer targets (make lint, make up, make down)
├── docker-compose.yml          # Core production/local control plane Docker stack
├── Caddyfile                   # Automatic TLS reverse proxy configuration (ports 80/443)
├── .env.template               # Source-of-truth environment template for the wizard & CI
├── lib/
│   └── wizard.sh               # Terminal UX, input validation, and cryptographic secret generators
├── docs/
│   ├── INSTALL.md              # Detailed A-Z VPS setup manual
│   └── ENVIRONMENT.md          # Exhaustive environment variable reference
└── .github/
    ├── workflows/ci.yml        # ShellCheck & Docker Compose validation CI
    ├── ISSUE_TEMPLATE/         # GitHub issue templates
    └── PULL_REQUEST_TEMPLATE.md# Pull request validation checklist
```

---

## 🛡️ Core Engineering Rules for AI Agents

### 1. Shell Scripting Standards (`install.sh`, `lib/wizard.sh`)
- **Strict ShellCheck Compliance:** Always run `make lint` or `shellcheck -x install.sh lib/wizard.sh` after any modification. Zero warnings allowed.
- **Directive Placement:** Never place commands like `set -a` between `# shellcheck disable=...` and the target line. ShellCheck directives must directly precede the line they annotate.
- **Interactive TTY Safety:** Never assume standard input is non-interactive. The installer checks `[ ! -t 0 ]` and provides a non-interactive mode via `--env-file=PATH`.
- **macOS vs Linux Differences:**
  - On macOS, Docker runs via Docker Desktop under the login user. Sudo must **not** be enforced for Docker commands on Darwin.
  - On Linux VPS, root/sudo is mandatory for system service orchestration.
- **Port Detection Safety:** When scanning ports using `lsof` or `netstat`, always use safe fallbacks to prevent pipeline failures with `set -eo pipefail`.

### 2. Docker & Compose Standards
- **Strict Compose V2 Syntax:** Use `docker compose` (Compose plugin v2), never legacy `docker-compose`.
- **Environment Isolation:** Never hardcode passwords or sensitive credentials into `docker-compose.yml`. Always use `${VAR:-fallback}` patterns backed by `.env`.
- **Volume Preservation:** The MySQL database volume (`mysql_data`) must retain its credentials once initialized. Notice how `install.sh` detects existing volumes to prevent breaking database auth on re-runs.
- **Health Checks:** Always provide container health checks (e.g. `mysqladmin ping` for MySQL, HTTP `/up` for the Laravel API).

### 3. Environment Variable Security
- **Safe Escaping:** Dotenv values containing spaces, quotes, or special characters must be properly escaped using `escape_env_value()` in `lib/wizard.sh`.
- **Never Commit Secrets:** `.env` and `.env.*` are strictly ignored by `.gitignore`. The template file `.env.template` must only contain dummy placeholder values.

### 4. Issue-First & Auto-Closing PR Workflow
- **Issue-First Policy:** Never start work or create a PR without an open, approved GitHub Issue.
- **GitHub Auto-Close Syntax:** Always link the issue in the PR description using `Closes #<issue_id>` (or `Fixes #<issue_id>` for bugs) so GitHub automatically closes the issue upon merge into `main`.
- **Contribution Skill:** Follow the complete workflow guide documented in [`.agents/skills/wp-next-contribution-workflow/SKILL.md`](.agents/skills/wp-next-contribution-workflow/SKILL.md).

### 5. Verification Workflow
Before finalizing any modification or reporting completion to the user, you **must** execute:
```bash
make lint
```
This ensures both:
1. `shellcheck -x install.sh lib/wizard.sh` passes with exit code 0.
2. `docker compose -f docker-compose.yml config` parses cleanly.
