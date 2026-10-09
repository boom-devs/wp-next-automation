# Contributing

Thanks for helping improve WP Next Automation.

## Ways to contribute

- Bug reports and install help (use issue templates)
- Fixes and features via pull requests
- Docs improvements
- Good first issues labeled `good first issue`

## Development setup

1. Fork and clone this meta-repo plus the component repos you need.
2. Recommended sibling layout:

```text
~/src/
  wp-next-automation/          # this repo
  frontis-cloud-portal/        # backend (or wp-next-automation-backend)
  wp-next-automation-dashbaord/
  wp-next-connector/
```

3. Copy env templates (never commit real secrets):

```bash
cp ../frontis-cloud-portal/.env.example ../frontis-cloud-portal/.env
cp ../wp-next-automation-dashbaord/.env.example ../wp-next-automation-dashbaord/.env
```

4. Run the stack:

```bash
docker compose up -d --build
```

5. Backend tests (in portal repo):

```bash
composer install
php artisan test
```

6. Dashboard checks:

```bash
npm ci
npm run lint
npm run typecheck
npm run build
```

## Pull requests

- Branch from `main`
- Prefer Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`
- Keep PRs focused
- Ensure CI passes
- Do not commit `.env`, tokens, or customer data
- Update docs when behavior or env vars change

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Security

Report vulnerabilities privately via [SECURITY.md](SECURITY.md) — do not open public issues for secrets or exploits.
