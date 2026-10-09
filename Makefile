.PHONY: lint up down wizard-help

lint:
	shellcheck -x install.sh lib/wizard.sh
	docker compose -f docker-compose.yml config >/dev/null

up:
	docker compose up -d --build

down:
	docker compose down

wizard-help:
	./install.sh --help
