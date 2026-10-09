# Security Policy

## Supported versions

Security fixes are applied to the latest `main` release line and the most recent SemVer tag.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Email the maintainers (or use GitHub Security Advisories on the repository) with:

- Description of the issue
- Steps to reproduce
- Impact assessment
- Whether you have a suggested fix

We aim to acknowledge reports within 72 hours.

## Secrets

Never commit API tokens, PATs, Stripe keys, or `.env` files. If you accidentally push a secret, rotate it immediately and notify maintainers.
