#!/usr/bin/env bash
# Копирует данные локальной dev-БД в БД на сервере (только данные, схему не трогает).
# Запуск НА МАКЕ:  ./deploy/seed-to-server.sh [ssh-цель]
# Пример:          ./deploy/seed-to-server.sh root@217.160.191.182
# ssh-цель можно задать аргументом, переменной SERVER или ниже по умолчанию.
set -euo pipefail

SERVER="${1:-${SERVER:-root@217.160.191.182}}"   # как ты заходишь на сервер по SSH
LOCAL_PG="${LOCAL_PG:-habit_postgres}"           # локальный контейнер postgres
REMOTE_PG="${REMOTE_PG:-habit_postgres}"         # контейнер postgres на сервере
DB="${DB:-habit_tracker}"
DB_USER="${DB_USER:-habit_user}"

# Таблицы с данными (без alembic_version — миграции сервера оставляем как есть).
TABLES="categories, fields, entries, entry_values, journal_entries, ai_reports"

echo "==> сервер: $SERVER"

echo "==> 1/3 чищу целевые таблицы на сервере"
ssh "$SERVER" "docker exec -i $REMOTE_PG psql -U $DB_USER -d $DB -v ON_ERROR_STOP=1 \
  -c 'TRUNCATE $TABLES RESTART IDENTITY CASCADE;'"

echo "==> 2/3 дамп локальной БД -> заливка на сервер (по трубе, без файла)"
docker exec "$LOCAL_PG" pg_dump -U "$DB_USER" -d "$DB" \
    --data-only --disable-triggers --exclude-table=alembic_version \
  | ssh "$SERVER" "docker exec -i $REMOTE_PG psql -U $DB_USER -d $DB -v ON_ERROR_STOP=1"

echo "==> 3/3 проверка (строки на сервере):"
ssh "$SERVER" "docker exec -i $REMOTE_PG psql -U $DB_USER -d $DB -tc \
  \"SELECT 'categories', count(*) FROM categories \
    UNION ALL SELECT 'entries', count(*) FROM entries \
    UNION ALL SELECT 'entry_values', count(*) FROM entry_values;\""

echo "==> готово. Обнови веб — увидишь свои данные."
