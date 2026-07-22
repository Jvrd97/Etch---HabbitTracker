# Деплой на VPS (тикет #02)

Целевая схема: VPS в tailnet, порты наружу не публикуются, доступ только через Tailscale (ADR-0003).

## Шаги (один раз)

1. Завести VPS (Ubuntu 22.04+, минимальный тариф достаточен). Поставить Docker: `curl -fsSL https://get.docker.com | sh`.
2. Поставить Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh && tailscale up` (логин под твоим аккаунтом).
3. Склонировать репозиторий в `/opt/habit-tracker` (или `rsync` папки `habit-tracker/` + `deploy/`).
4. Задать ключ: `echo "API_KEY=<длинный случайный ключ>" > /opt/habit-tracker/habit-tracker/.env` (генерация: `openssl rand -hex 32`).
5. Запуск:

```bash
cd /opt/habit-tracker/habit-tracker
docker compose -f docker-compose.yml -f ../deploy/docker-compose.prod.yml up -d --build
docker compose exec backend alembic upgrade head
```

6. Бэкапы: `chmod +x /opt/habit-tracker/deploy/backup.sh` и добавить в crontab строку из шапки скрипта. Один раз проверить восстановление дампа.

## Проверка acceptance

- С iPhone (Tailscale включён): `http://<magicdns-имя>:8000/docs` открывается, Authorize с API-ключом работает.
- Из открытого интернета `curl http://<публичный-ip>:8000` — таймаут/refused. Если порт виден — закрыть публикацию 8000 на публичном интерфейсе (ufw или binding на tailscale0).
- `docker ps` — оба контейнера `restart: always`.

## Обновление версии

```bash
cd /opt/habit-tracker && git pull
cd habit-tracker && docker compose -f docker-compose.yml -f ../deploy/docker-compose.prod.yml up -d --build
docker compose exec backend alembic upgrade head
```
