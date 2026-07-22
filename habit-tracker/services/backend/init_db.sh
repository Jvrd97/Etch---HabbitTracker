#!/bin/bash

# Скрипт для инициализации базы данных
# Создаёт миграции и применяет их

echo "🔄 Waiting for PostgreSQL to be ready..."
while ! nc -z postgres 5432; do
  sleep 0.1
done
echo "✅ PostgreSQL is ready!"

echo "📝 Creating initial migration..."
alembic revision --autogenerate -m "Initial migration"

echo "🚀 Applying migrations..."
alembic upgrade head

echo "✅ Database initialized successfully!"
