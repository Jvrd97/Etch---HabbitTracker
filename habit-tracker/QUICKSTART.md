# 🚀 Быстрый старт

## Запуск за 3 шага

### 1. Запустите Docker Compose

```bash
cd habit-tracker
docker-compose up --build
```

Подождите, пока все сервисы запустятся. Вы увидите:
```
✅ PostgreSQL is healthy
🚀 Starting Habit Tracker API...
📚 Documentation: http://localhost:8000/docs
```

### 2. Создайте миграции БД

В **новом терминале**:

```bash
# Создать миграцию
docker-compose exec backend alembic revision --autogenerate -m "Initial migration"

# Применить миграцию
docker-compose exec backend alembic upgrade head
```

### 3. Откройте API документацию

Перейдите в браузере:
```
http://localhost:8000/docs
```

Вы увидите полную интерактивную документацию Swagger UI!

---

## 📝 Первые шаги с API

### Тест 1: Создайте категорию "Сон"

В Swagger UI найдите `POST /api/v1/categories`, нажмите "Try it out" и вставьте:

```json
{
  "name": "Сон",
  "description": "Отслеживание качества сна",
  "color": "#3B82F6",
  "fields": [
    {
      "name": "Продолжительность (часы)",
      "field_type": "number",
      "is_required": true,
      "order": 1
    },
    {
      "name": "Качество",
      "field_type": "select",
      "options": "плохо,средне,отлично",
      "order": 2
    }
  ]
}
```

Нажмите "Execute". Вы получите `category_id: 1`.

### Тест 2: Добавьте запись о сне

Найдите `POST /api/v1/entries` и вставьте:

```json
{
  "category_id": 1,
  "entry_date": "2024-01-15",
  "notes": "Хорошо выспался",
  "values": [
    {"field_id": 1, "value": "8"},
    {"field_id": 2, "value": "отлично"}
  ]
}
```

### Тест 3: Получите все записи

Найдите `GET /api/v1/entries` и нажмите "Execute".

Вы увидите вашу запись!

### Тест 4: Создайте дневниковую запись

Найдите `POST /api/v1/journal` и вставьте:

```json
{
  "title": "Отличный день!",
  "content": "Сегодня был очень продуктивный день. Закончил настройку проекта!",
  "entry_date": "2024-01-15",
  "mood": "happy",
  "tags": "работа,достижения"
}
```

---

## 🧪 Тестирование через curl

### Создать категорию
```bash
curl -X POST "http://localhost:8000/api/v1/categories" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Витамины",
    "description": "Ежедневные витамины",
    "color": "#10B981",
    "fields": [
      {"name": "Название", "field_type": "text", "is_required": true},
      {"name": "Дозировка (мг)", "field_type": "number"}
    ]
  }'
```

### Получить все категории
```bash
curl "http://localhost:8000/api/v1/categories"
```

### Добавить запись
```bash
curl -X POST "http://localhost:8000/api/v1/entries" \
  -H "Content-Type: application/json" \
  -d '{
    "category_id": 2,
    "entry_date": "2024-01-15",
    "values": [
      {"field_id": 3, "value": "Витамин D"},
      {"field_id": 4, "value": "1000"}
    ]
  }'
```

---

## 🛑 Остановка

```bash
# Остановить контейнеры
docker-compose down

# Остановить и удалить все данные (включая БД)
docker-compose down -v
```

---

## 🔧 Разработка

### Просмотр логов

```bash
# Все сервисы
docker-compose logs -f

# Только backend
docker-compose logs -f backend

# Только postgres
docker-compose logs -f postgres
```

### Подключение к БД

```bash
docker-compose exec postgres psql -U habit_user -d habit_tracker
```

Команды PostgreSQL:
```sql
-- Показать все таблицы
\dt

-- Показать структуру таблицы
\d categories

-- Выполнить запрос
SELECT * FROM categories;

-- Выйти
\q
```

### Пересоздание миграций

```bash
# Удалить все миграции
rm services/backend/alembic/versions/*.py

# Создать заново
docker-compose exec backend alembic revision --autogenerate -m "Recreate schema"
docker-compose exec backend alembic upgrade head
```

---

## 📊 Примеры категорий для тестирования

### Сон
```json
{
  "name": "Сон",
  "color": "#3B82F6",
  "fields": [
    {"name": "Продолжительность", "field_type": "number"},
    {"name": "Качество", "field_type": "select", "options": "плохо,средне,отлично"},
    {"name": "Время отхода", "field_type": "time"},
    {"name": "Время подъёма", "field_type": "time"}
  ]
}
```

### Тренировки
```json
{
  "name": "Тренировки",
  "color": "#EF4444",
  "fields": [
    {"name": "Тип", "field_type": "select", "options": "кардио,силовая,йога,плавание"},
    {"name": "Продолжительность (мин)", "field_type": "number"},
    {"name": "Калории", "field_type": "number"},
    {"name": "Интенсивность (1-10)", "field_type": "number"}
  ]
}
```

### Питание
```json
{
  "name": "Питание",
  "color": "#10B981",
  "fields": [
    {"name": "Калории", "field_type": "number"},
    {"name": "Белки (г)", "field_type": "number"},
    {"name": "Углеводы (г)", "field_type": "number"},
    {"name": "Жиры (г)", "field_type": "number"},
    {"name": "Вода (мл)", "field_type": "number"}
  ]
}
```

### Настроение
```json
{
  "name": "Настроение",
  "color": "#F59E0B",
  "fields": [
    {"name": "Оценка (1-10)", "field_type": "number"},
    {"name": "Энергия", "field_type": "select", "options": "низкая,средняя,высокая"},
    {"name": "Стресс", "field_type": "select", "options": "низкий,средний,высокий"},
    {"name": "Медитация (мин)", "field_type": "number"}
  ]
}
```

---

## ❓ Проблемы?

### Порт 8000 занят
```bash
# Измените порт в docker-compose.yml
ports:
  - "8001:8000"  # Вместо 8000:8000
```

### Ошибка подключения к БД
```bash
# Убедитесь, что PostgreSQL запустился
docker-compose logs postgres

# Пересоздайте контейнеры
docker-compose down -v
docker-compose up --build
```

### Миграции не применяются
```bash
# Проверьте статус
docker-compose exec backend alembic current

# Примените принудительно
docker-compose exec backend alembic upgrade head

# Если не помогло, пересоздайте БД
docker-compose down -v
docker-compose up -d postgres
# Подождите 10 секунд
docker-compose up backend
```

---

Удачи! 🚀
