# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-10-07

### Added
- Interactive `install.sh` wizard (domains, Coolify, GitHub, optional Stripe/SMTP)
- Docker Compose control-plane stack (portal, worker, scheduler, dashboard, MySQL, Redis, Reverb, Caddy)
- CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, issue/PR templates, CI (shellcheck + compose validate)
- Vendor-neutral env templates (no embedded secrets)
