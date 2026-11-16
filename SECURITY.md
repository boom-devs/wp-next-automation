# Security Policy

## Supported Versions

We take the security of **WP Next Automation** seriously. Security updates are actively maintained and released for the following versions:

| Version | Supported | Status |
| :--- | :--- | :--- |
| `1.0.x` | ✅ Yes | Current Active Release |
| `< 1.0.0`| ❌ No | Deprecated Pre-release |

---

## Reporting a Vulnerability

If you discover a security vulnerability within WP Next Automation, please follow responsible disclosure guidelines. **Do not disclose security vulnerabilities in public GitHub issues, discussions, or pull requests.**

### How to Report

1. **GitHub Private Vulnerability Reporting (Preferred):**  
   Navigate to the repository's **Security** tab ➔ **Advisories** ➔ **Report a vulnerability**. This creates a confidential disclosure draft directly with the core maintainers.

2. **Direct Maintainer Contact:**  
   If you cannot use GitHub Advisories, please email the security maintainers at:
   - **`security@boomdevs.com`** or **`noruzzamanrubel@gmail.com`**
   - Please include `[SECURITY] WP Next Automation Vulnerability Report` in the subject line.

### What to Include in Your Report

To help us triage and resolve the issue quickly, please provide:
- A detailed description of the vulnerability and attack vector.
- Clear, reproducible step-by-step instructions (or a minimal Proof of Concept).
- Potential impact on hosted sites, control planes, or API credentials.
- Any suggested remediations or mitigations, if available.

### Response Timelines & SLA

- **Initial Acknowledgment:** Within 24–48 hours of receipt.
- **Triage & Severity Assessment:** Within 72 hours.
- **Patch Development & Testing:** Priority based on CVSS score.
- **Public Disclosure:** Coordinated after a patched release is published.

---

## Zero-Trust Secrets Management

- **External Integrations:** Coolify API tokens, GitHub Personal Access Tokens (PATs), and Stripe API keys are stored encrypted at rest.
- **Credential Hygiene:** Never commit `.env` files, production database dumps, or private keys to source control.
- **Compromise Procedure:** If an API secret is inadvertently exposed in logs or commits, immediately revoke and regenerate the token from the relevant provider dashboard (Coolify, GitHub, Stripe).
