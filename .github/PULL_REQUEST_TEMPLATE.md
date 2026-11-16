## 📋 Summary

Provide a concise summary of the changes proposed in this Pull Request.

- 

---

## 🔗 Related Issues & Auto-Closing

<!--
  IMPORTANT: Link your PR to an approved GitHub Issue so that GitHub automatically
  closes the issue upon merge into 'main'.
  
  Supported keywords:
  - Closes #123     (for features / general tasks)
  - Fixes #123      (for bug fixes)
  - Resolves #123   (for architectural / technical resolutions)
  
  Example: Closes #10
-->
Closes #

---

## 🔍 Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 🔨 Refactor or performance enhancement
- [ ] 📝 Documentation update
- [ ] 🔧 Infrastructure, CI/CD, or build configuration

---

## 🧪 Verification & Test Plan

Describe how you tested these changes:
- [ ] Tested `./install.sh` on local or VPS environment.
- [ ] Verified `make lint` passes locally with exit code 0 (`shellcheck -x install.sh lib/wizard.sh`).
- [ ] Validated `docker compose -f docker-compose.yml config` passes without syntax errors.
- [ ] Confirmed zero private secrets, API tokens, or `.env` keys are committed.
