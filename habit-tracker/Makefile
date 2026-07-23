PHONY: build

build:
	docker compose -f docker-compose.yml -f ../deploy/docker-compose.prod.yml up -d --build \
	&& docker compose exec backend alembic upgrade head
