# habit-tracker/Makefile — deploy & ops shortcuts (run from this dir on the VPS)
# Prod stack = base compose + prod override + the optional `web` (frontend) profile.
COMPOSE = docker compose --profile web -f docker-compose.yml -f ../deploy/docker-compose.prod.yml

.DEFAULT_GOAL := help
.PHONY: help up down stop restart logs ps build migrate deploy backup enable-boot

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Build and start everything (backend, frontend, postgres), detached
	$(COMPOSE) up -d --build

down: ## Stop and remove containers (DB volume is kept)
	$(COMPOSE) down

stop: ## Stop containers without removing them
	$(COMPOSE) stop

restart: ## Restart all running services
	$(COMPOSE) restart

logs: ## Follow logs of all services
	$(COMPOSE) logs -f --tail=100

ps: ## Show container status
	$(COMPOSE) ps

build: ## Rebuild images without starting
	$(COMPOSE) build

migrate: ## Apply DB migrations (alembic upgrade head)
	$(COMPOSE) exec backend alembic upgrade head

deploy: ## Full redeploy: pull main, rebuild, restart, migrate
	git -C .. pull origin main
	$(COMPOSE) up -d --build
	$(COMPOSE) exec backend alembic upgrade head

backup: ## Run a one-off DB backup (see deploy/backup.sh)
	bash ../deploy/backup.sh

enable-boot: ## Make Docker (and restart:always containers) start on system boot
	sudo systemctl enable --now docker
	@echo "Docker enabled on boot. Containers use 'restart: always', so they auto-start."
