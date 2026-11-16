---
name: wp-next-contribution-workflow
description: >-
  Standardized open-source contribution workflow for WP Next Automation: Issue-first policy,
  how GitHub auto-closes issues on PR merge (Closes #<id>), Conventional Commits,
  AI agent quality standards, and maintainer review flow.
---

# WP Next Automation — Contribution & Workflow Standards

This skill documents the complete open-source engineering workflow, issue-linking standards, AI agent conventions, and code review policies for **WP Next Automation**.

---

## 🎯 1. Issue-First Policy (Zero Orphan PRs)

> [!IMPORTANT]
> **No Pull Request without an approved issue:**
> WP Next Automation strictly enforces an **Issue-First Policy**. Every pull request **MUST** link to an open, approved GitHub Issue. Unsolicited or "orphan" PRs submitted without an existing issue will be placed on hold.

### The 4-Step Contribution Flow:
1. **Open an Issue First:**  
   Always open a detailed issue describing the problem, proposed solution, and task checklist before touching code.
   ```bash
   gh issue create --title "feat(installer): add automated MariaDB volume backup" --body "..."
   ```
2. **Discuss & Get Assigned:**  
   Maintainers (`@EnamulHaq`, `@noruzzamans`) review, label, and assign the issue.
3. **Develop on a Feature Branch:**  
   Branch off `main` with a descriptive name:
   ```bash
   git checkout -b feature/mariadb-volume-backup
   ```
4. **Open the PR with Closing Keywords (`Closes #<id>`):**  
   Always include a GitHub closing keyword in the PR description so that merging the PR automatically closes the issue.

---

## 🔗 2. How GitHub Links & Auto-Closes Issues on PR Merge

GitHub provides native bidirectional linking between Pull Requests and Issues. When a PR is merged into the default branch (`main`), GitHub parses the PR description for specific **closing keywords** and **automatically closes the linked issue**.

### Supported Closing Keywords
You can use any of the following keywords followed by the issue number:

| Keyword | Syntax Example | When to Use |
| :--- | :--- | :--- |
| `Closes` | `Closes #10` | Standard for features, tasks, and documentation |
| `Fixes` | `Fixes #10` | Used when resolving bug reports |
| `Resolves`| `Resolves #10` | Used when resolving architectural or configuration discussions |

> [!TIP]
> **Multi-Issue Linking:**  
> If a PR resolves multiple issues, repeat the keyword for each issue:
> ```text
> Closes #12, Closes #15, Fixes #18
> ```

### Rules for Auto-Closing to Work:
1. The closing keyword must be in the **PR description** (the initial opening comment) or a commit message on the PR branch.
2. The PR must be merged into the repository's **default branch** (`main`). Merging into another feature branch will link the issue but will not close it until that branch reaches `main`.
3. Do not use punctuation between the keyword and the issue reference (e.g. use `Closes #10`, not `Closes: #10`).

---

## 🏷️ 3. Title Convention (Conventional Commits)

All Issue and Pull Request titles must strictly follow the **Conventional Commits** specification:

```text
<type>(<scope>): <imperative description in present tense>
```

### Approved Types
| Type | Purpose | Example |
| :--- | :--- | :--- |
| `feat` | New feature, service, or installer capability | `feat(dx): add docker-compose.dev.yml sandbox` |
| `fix` | Bug fix, syntax regression, or permission patch | `fix(installer): resolve ShellCheck SC1090 warning` |
| `docs` | Documentation, guides, or skills | `docs(connector): add manual pairing instructions` |
| `ci` | GitHub Actions workflows and automation | `ci: add multi-arch Docker build workflow` |
| `refactor` | Code restructuring with zero behavior change | `refactor(wizard): modularize input prompts` |
| `chore` | Dependency updates, tooling, or ignore files | `chore(deps): update actions/checkout to v7` |

### Approved Scopes
`installer` · `docker` · `backend` · `dashboard` · `connector` · `coolify` · `ci-cd` · `dx`

---

## 📋 4. Pull Request Description Standard

Every PR must follow [`.github/PULL_REQUEST_TEMPLATE.md`](file:///Users/noruzzamanrubel/Desktop/wp-next-automation/.github/PULL_REQUEST_TEMPLATE.md):

```markdown
## 📋 Summary
Concise description of what this PR accomplishes.

Closes #<issue_number>

---

## 🔍 Key Capabilities
- Bullet point 1
- Bullet point 2

---

## 🧪 Verification & Test Plan
- [x] Verified `make lint` passes locally with exit code 0.
- [x] Tested installer or Docker Compose configuration.
- [x] Confirmed zero secret leaks.
```

---

## 🤖 5. AI Coding Agent Policy (Cursor, Copilot, Antigravity, Claude Code)

AI coding agents are first-class contributors to WP Next Automation, subject to strict engineering rigor:

1. **Mandatory Lint Verification:**  
   Before completing any task or opening a PR, the agent **MUST** run:
   ```bash
   make lint
   ```
   Both ShellCheck and Docker Compose config validation must pass with exit code `0`. Zero warnings allowed.
2. **Zero-Trust Secret Handling:**  
   Never commit `.env` files, production database credentials, API keys, or JWT tokens. Always use `.env.template` with dummy placeholders.
3. **Interactive TTY Safety:**  
   Always check `[ ! -t 0 ]` in shell scripts; never assume a terminal is interactive.
4. **macOS vs Linux Isolation:**  
   Never enforce `sudo` for Docker commands on macOS (Darwin).
5. **Atomic Diffs:**  
   Keep changes minimal, clean, and directly scoped to the assigned issue.

---

## 👥 6. Maintainer Review Flow

- **Code Owners:** Universal review is configured via `.github/CODEOWNERS` for `@EnamulHaq` and `@noruzzamans`.
- **Automated Triage:** PRs are automatically labeled by size (`size: XS` to `size: XL`), focus area, and assigned for review.
- **Merge Strategy:** Pull requests are merged using **Squash and Merge** to maintain a linear, clean commit history on `main`.
