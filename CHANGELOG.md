# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-16

### 🚀 Major Open-Source Launch

This marks the official `1.0.0` open-source release of **WP Next Automation**, the self-hosted control plane for automated Headless WordPress and Next.js sites on Coolify.

### ✨ Added
- **Multi-Architecture Docker Build Pipeline:** Automated GitHub Actions workflow (`.github/workflows/docker-publish.yml`) building and publishing multi-platform (`linux/amd64`, `linux/arm64`) container images to GitHub Packages (GHCR) with provenance attestation and caching ([#2](https://github.com/boom-devs/wp-next-automation/issues/2), [#6](https://github.com/boom-devs/wp-next-automation/pull/6)).
- **Local Development Sandbox:** Dedicated `docker-compose.dev.yml` override profile with live volume binds, host port mappings (`8010`, `3010`, `13306`, `16379`), and one-line developer targets: `make dev`, `make dev-down`, and `make dev-logs` ([#3](https://github.com/boom-devs/wp-next-automation/issues/3), [#7](https://github.com/boom-devs/wp-next-automation/pull/7)).
- **Cross-Platform CI Matrix:** Expanded CI validation matrix across Ubuntu (`ubuntu-latest`) and macOS (`macos-latest`) runners testing ShellCheck, Compose v2 parsing, and development overrides ([#4](https://github.com/boom-devs/wp-next-automation/issues/4), [#8](https://github.com/boom-devs/wp-next-automation/pull/8)).
- **WordPress Connector Distribution Guide:** Architectural documentation for the companion `wp-next-connector` plugin, webhook payloads, token security, and manual zip deployment fallback in [`docs/CONNECTOR_PLUGIN.md`](docs/CONNECTOR_PLUGIN.md) ([#5](https://github.com/boom-devs/wp-next-automation/issues/5), [#9](https://github.com/boom-devs/wp-next-automation/pull/9)).
- **AI Agent & Contributor Workflow Standards:** Formalized contribution guidelines, strict Issue-First policy, and automated GitHub PR issue-linking (`Closes #<id>`) in [`.agents/skills/wp-next-contribution-workflow/SKILL.md`](.agents/skills/wp-next-contribution-workflow/SKILL.md) ([#10](https://github.com/boom-devs/wp-next-automation/issues/10), [#11](https://github.com/boom-devs/wp-next-automation/pull/11)).
- **Interactive Installer Wizard:** Robust CLI installer (`install.sh`) supporting domain configuration, Coolify API pairing, GitHub credentials, database health detection, and optional Stripe/SMTP setup.
- **Production Control Plane Stack:** Docker Compose v2 topology orchestrating Laravel Backend API, Queue Worker, Scheduler, WebSocket Reverb server, Next.js Dashboard, MySQL 8.0, Redis 7.2, and Caddy with automatic TLS.
- **Community Automation Suite:** First-time contributor welcome bot, PR size and component auto-labeling (`.github/labeler.yml`), issue topic triage, Dependabot weekly updates, and `.all-contributorsrc` specification.
- **Frontis-Style Maintainer Showcase:** High-converting `README.md` featuring Mermaid architecture flowcharts, Headless vs Traditional WordPress comparison matrix, and maintainer showcase for Md. Enamul Haq and Md. Noruzzaman.

### 🛡️ Security & Hardening
- ShellCheck strict compliance across `install.sh` and `lib/wizard.sh` with zero warnings.
- Cryptographic secret generation using OpenSSL (`rand -hex 32`) for `APP_KEY`, `JWT_SECRET`, and database passwords.
- Environment isolation: `.env.template` contains only dummy placeholders; production credentials are never committed.
- Formalized `SECURITY.md` vulnerability reporting SLA with BoomDevs Security Team (`security@boomdevs.com`).

[1.0.0]: https://github.com/boom-devs/wp-next-automation/releases/tag/v1.0.0
