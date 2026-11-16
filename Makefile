.PHONY: lint up down dev dev-down dev-logs wizard-help

lint:
	shellcheck -x install.sh lib/wizard.sh
	docker compose -f docker-compose.yml config >/dev/null
	docker compose -f docker-compose.yml -f docker-compose.dev.yml config >/dev/null

up:
	docker compose up -d --build

down:
	docker compose down

dev:
	docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

dev-down:
	docker compose -f docker-compose.yml -f docker-compose.dev.yml down

dev-logs:
	docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

wizard-help:
	./install.sh --help
