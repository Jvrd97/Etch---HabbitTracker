# 🏗️ Архитектурные решения

Этот документ объясняет ключевые архитектурные решения, принятые при разработке Habit Tracker.

---

## 1. Выбор модели данных: EAV (Entity-Attribute-Value)

### Решение
Использовать **EAV паттерн** вместо традиционных статических таблиц.

### Альтернативы
1. **Статические таблицы** - отдельная таблица для каждой категории
2. **JSONB в PostgreSQL** - хранить данные в JSON полях
3. **MongoDB** - NoSQL база данных

### Почему EAV?

#### ✅ Преимущества

**1. Динамическая структура**
```sql
-- Без EAV: нужно создавать новые таблицы
CREATE TABLE sleep_tracking (duration INT, quality TEXT);
CREATE TABLE vitamin_tracking (name TEXT, dosage INT);
-- Каждая категория = новая миграция!

-- С EAV: одна структура для всех
-- Пользователь создаёт категории через UI/API
-- Никаких миграций для новых категорий
```

**2. Простота масштабирования**
- Добавление новых категорий не требует изменения схемы БД
- Нет лимита на количество категорий
- Легко добавлять/удалять поля

**3. Гибкость для пользователя**
```json
// Пользователь 1: трекает сон
{
  "category": "Sleep",
  "fields": ["duration", "quality", "dreams"]
}

// Пользователь 2: трекает тренировки
{
  "category": "Workout",
  "fields": ["type", "calories", "heart_rate", "intensity"]
}

// Одна и та же БД поддерживает любые кейсы!
```

#### ❌ Недостатки (и как мы с ними справляемся)

**1. Производительность**
```sql
-- Сложный JOIN для получения данных
SELECT e.*, ev.field_id, ev.value
FROM entries e
JOIN entry_values ev ON e.id = ev.entry_id
JOIN fields f ON ev.field_id = f.id
```

**Решение:**
- Используем индексы на foreign keys
- Eager loading через SQLAlchemy (`selectinload`)
- Кеширование на уровне приложения (TODO)

**2. Типизация**
Все значения хранятся как строки (`value TEXT`)

**Решение:**
```python
class Field:
    field_type = Enum(FieldType)  # знаем тип поля

# При чтении преобразуем
def parse_value(field: Field, value: str):
    if field.field_type == FieldType.NUMBER:
        return float(value)
    if field.field_type == FieldType.BOOLEAN:
        return value.lower() == 'true'
    # и т.д.
```

### Почему НЕ JSONB?

```sql
-- JSONB подход
CREATE TABLE entries (
    id INT,
    category_id INT,
    data JSONB  -- {"duration": 8, "quality": "good"}
);
```

**Минусы:**
- Нет схемы данных - сложно валидировать
- Нет foreign keys - можно случайно удалить поля
- Сложнее индексировать и искать
- Нет истории изменений схемы

### Почему НЕ MongoDB?

**Минусы:**
- Меньше ACID гарантий
- Сложнее делать JOIN'ы для аналитики
- PostgreSQL даёт JSONB если нужно + реляционность
- Команда привыкла к SQL

---

## 2. Async/Await архитектура

### Решение
Использовать **асинхронный** FastAPI и SQLAlchemy.

### Альтернативы
1. **Синхронный** FastAPI + SQLAlchemy
2. **Django** с Django ORM
3. **Flask** с SQLAlchemy

### Почему Async?

#### Производительность

```python
# Синхронный код
def get_data():
    result1 = db.query(...)  # 100ms - блокирует поток
    result2 = db.query(...)  # 100ms - блокирует поток
    return merge(result1, result2)
# Итого: 200ms

# Асинхронный код
async def get_data():
    result1, result2 = await asyncio.gather(
        db.execute(...),  # 100ms - не блокирует
        db.execute(...)   # 100ms - не блокирует
    )
    return merge(result1, result2)
# Итого: 100ms (параллельно!)
```

#### Масштабируемость

**Синхронный сервер:**
```
1000 запросов = 1000 потоков = ~1GB RAM
```

**Async сервер:**
```
1000 запросов = 1 поток + event loop = ~100MB RAM
```

#### Когда это важно?

- Много I/O операций (БД, API, файлы)
- Много параллельных пользователей
- Микросервисная архитектура (межсервисные вызовы)

### Почему НЕ Django?

**Плюсы Django:**
- Admin панель из коробки
- ORM проще для новичков
- Больше батареек

**Почему FastAPI:**
- Лучше для API-first подхода
- Быстрее (благодаря async)
- Автодокументация (Swagger)
- Лучше типизация через Pydantic
- Современный подход

```python
# Django view
def create_category(request):
    data = json.loads(request.body)
    category = Category.objects.create(**data)
    return JsonResponse(serialize(category))

# FastAPI endpoint
@app.post("/categories", response_model=CategoryResponse)
async def create_category(category: CategoryCreate):
    return await crud.create_category(db, category)
    # ✅ Автоматическая валидация
    # ✅ Автоматическая сериализация
    # ✅ Автодокументация
```

---

## 3. Микросервисная архитектура

### Решение
Разделить на **независимые сервисы**: Backend, Frontend, AI.

### Альтернативы
1. **Монолит** - всё в одном приложении
2. **Модульный монолит** - разделение внутри одного приложения

### Почему микросервисы?

#### Независимое развёртывание

```
backend:
  - Обновление логики БД
  - Новые API endpoints
  - Не влияет на Frontend!

frontend:
  - Новый дизайн
  - Новые фичи UI
  - Backend продолжает работать!

ai-service:
  - Новые AI модели
  - Эксперименты
  - Не ломает основной функционал!
```

#### Масштабирование

```yaml
# docker-compose.prod.yml
services:
  backend:
    deploy:
      replicas: 5  # 5 экземпляров Backend

  frontend:
    deploy:
      replicas: 3  # 3 экземпляра Frontend

  ai-service:
    deploy:
      replicas: 2  # AI требует меньше экземпляров
```

#### Технологическое разнообразие

```
backend:     Python + FastAPI + PostgreSQL
frontend:    TypeScript + Next.js + React
ai-service:  Python + LangChain + Ollama
```

Каждый сервис использует лучшие инструменты для своей задачи.

### Недостатки (и решения)

**1. Сложность инфраструктуры**

Решение: Docker Compose для разработки, Kubernetes для production

**2. Межсервисная коммуникация**

```python
# Backend -> AI Service
async def get_ai_insights(category_id: int):
    response = await httpx.get(
        f"http://ai-service:8001/analyze/{category_id}"
    )
    return response.json()
```

**3. Distributed транзакции**

В нашем случае не критично - AI сервис читает данные, не пишет.

---

## 4. Repository Pattern (CRUD)

### Решение
Изолировать всю логику БД в **CRUD модулях**.

### Структура

```
app/
├── api/          # HTTP endpoints
├── crud/         # Database operations
├── models/       # SQLAlchemy models
└── schemas/      # Pydantic schemas
```

### Почему это важно?

#### Разделение ответственности

```python
# ❌ Плохо: логика БД в endpoint
@app.post("/categories")
async def create_category(category: CategoryCreate):
    db_category = Category(**category.dict())
    db.add(db_category)

    for field in category.fields:
        db_field = Field(**field.dict())
        db.add(db_field)

    await db.commit()
    # Сложно тестировать, сложно переиспользовать

# ✅ Хорошо: логика в CRUD
@app.post("/categories")
async def create_category(category: CategoryCreate):
    return await crud.create_category(db, category)
    # Чисто, тестируемо, переиспользуемо
```

#### Тестируемость

```python
# Тестируем CRUD независимо
async def test_create_category():
    category = CategoryCreate(name="Test")
    result = await crud.create_category(db, category)
    assert result.name == "Test"

# Тестируем API с mock CRUD
@patch('app.crud.category.create_category')
async def test_api(mock_crud):
    mock_crud.return_value = fake_category
    response = client.post("/categories", json={...})
    assert response.status_code == 201
```

#### Переиспользование

```python
# API endpoint
@app.post("/categories")
async def api_create_category(...):
    return await crud.create_category(db, category)

# Background task
async def import_categories_from_file(file):
    for cat_data in parse_file(file):
        await crud.create_category(db, cat_data)

# Admin script
async def seed_default_categories():
    for cat in DEFAULT_CATEGORIES:
        await crud.create_category(db, cat)
```

---

## 5. Pydantic для валидации

### Решение
Использовать **Pydantic schemas** для валидации и сериализации.

### Альтернативы
1. Ручная валидация
2. Marshmallow
3. Django serializers

### Почему Pydantic?

#### Автоматическая валидация

```python
class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    color: Optional[str] = Field(None, pattern=r'^#[0-9A-Fa-f]{6}$')

# Валидация происходит автоматически!
@app.post("/categories")
async def create_category(category: CategoryCreate):
    # Если данные невалидны, FastAPI вернёт 422
    # с подробным описанием ошибок
    pass
```

**Что проверяется:**
- Типы данных (`str`, `int`, `bool`)
- Длина строк (`min_length`, `max_length`)
- Regex паттерны (`pattern`)
- Вложенные объекты
- Кастомные валидаторы

#### Отличная интеграция с FastAPI

```python
class CategoryResponse(BaseModel):
    id: int
    name: str
    created_at: datetime

    class Config:
        from_attributes = True  # Работает с SQLAlchemy

# Автоматическая сериализация
@app.get("/categories/{id}", response_model=CategoryResponse)
async def get_category(id: int):
    return db_category  # Автоматически -> JSON
```

#### Документация

```python
class FieldCreate(BaseModel):
    name: str = Field(..., description="Название поля")
    field_type: str = Field(
        ...,
        description="Тип поля: text, number, date, etc."
    )

# В Swagger UI это отобразится с описаниями!
```

---

## 6. Docker & Docker Compose

### Решение
Контейнеризация **всех** сервисов.

### Почему Docker?

#### Консистентность окружения

```
Разработка:    Python 3.10, PostgreSQL 16, Linux
Staging:       Python 3.10, PostgreSQL 16, Linux
Production:    Python 3.10, PostgreSQL 16, Linux

Одинаково везде! ✅
```

#### Простота setup

**Без Docker:**
```bash
# Установить PostgreSQL
sudo apt-get install postgresql-16

# Создать БД
sudo -u postgres createdb habit_tracker

# Установить Python зависимости
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Настроить переменные окружения
export DATABASE_URL=...

# Запустить
uvicorn app.main:app
```

**С Docker:**
```bash
docker-compose up
# Готово! ✅
```

#### Изоляция

```
Проект 1: PostgreSQL 14
Проект 2: PostgreSQL 16
Проект 3: PostgreSQL 17

Все работают одновременно без конфликтов!
```

---

## 7. Alembic для миграций

### Решение
Управление схемой БД через **миграции**.

### Альтернативы
1. Ручные SQL скрипты
2. SQLAlchemy create_all()

### Почему миграции?

#### История изменений

```bash
git log alembic/versions/
# 2024_01_15_1030-abc123_initial_migration.py
# 2024_01_16_1420-def456_add_mood_to_journal.py
# 2024_01_17_0900-ghi789_add_user_model.py

# Видим, когда и что изменилось!
```

#### Откат изменений

```bash
# Что-то пошло не так?
alembic downgrade -1  # Откатить последнюю миграцию

# Или к конкретной версии
alembic downgrade abc123
```

#### Работа в команде

```python
# Developer A
alembic revision -m "Add user_id to categories"

# Developer B (pull changes)
alembic upgrade head  # Применить миграции

# Автоматическая синхронизация схемы!
```

#### Автогенерация

```python
# Изменили модель
class Category(Base):
    new_field = Column(String)  # Добавили поле

# Alembic автоматически определит изменение
alembic revision --autogenerate -m "Add new_field"

# Создаст миграцию:
def upgrade():
    op.add_column('categories',
        sa.Column('new_field', sa.String(), nullable=True)
    )
```

---

## 8. API-First подход

### Решение
**Backend - это API**, Frontend потребляет API.

### Альтернативы
1. Server-Side Rendering (Django templates, etc.)
2. Monolithic MVC

### Почему API-First?

#### Гибкость клиентов

```
Backend API
    ↓
    ├─→ Web Frontend (Next.js)
    ├─→ Mobile App (React Native)
    ├─→ Desktop App (Electron)
    └─→ Third-party integrations
```

Один API для всех платформ!

#### Лучший DX (Developer Experience)

```python
# Backend: чистый API
@app.get("/categories")
async def get_categories():
    return await crud.get_categories(db)

# Frontend: чистый UI
function CategoriesList() {
    const { data } = useQuery('/api/categories')
    return <div>{data.map(...)}</div>
}

# Разделены ответственности!
```

#### Автодокументация

FastAPI автоматически генерирует:
- **Swagger UI** - интерактивная документация
- **ReDoc** - красивая документация
- **OpenAPI schema** - для генерации клиентов

```typescript
// Можно автогенерировать TypeScript типы!
type Category = {
  id: number
  name: string
  color: string
}
```

---

## 9. Планирование AI интеграции

### Решение
Отдельный **AI микросервис** для анализа данных.

### Архитектура

```
┌─────────────┐
│   Backend   │
│  (FastAPI)  │
└──────┬──────┘
       │
       ├─→ PostgreSQL (данные)
       │
       └─→ ┌─────────────┐
           │ AI Service  │
           │ (LangChain) │
           └──────┬──────┘
                  │
                  └─→ Ollama / OpenAI
```

### Почему отдельный сервис?

#### Изоляция ресурсов

```yaml
# AI Service требует много RAM/GPU
ai-service:
  deploy:
    resources:
      reservations:
        memory: 8G
        devices:
          - capabilities: [gpu]

# Backend работает отдельно
backend:
  deploy:
    resources:
      limits:
        memory: 512M
```

#### Независимое масштабирование

- Backend: обрабатывает CRUD операции (быстро)
- AI Service: обрабатывает анализ (медленно, требует ресурсов)

Можем масштабировать отдельно!

#### Эксперименты

```python
# Можем менять AI модели без изменения Backend
class AIService:
    def __init__(self):
        # self.llm = OpenAI()
        self.llm = Ollama("llama2")
        # self.llm = LocalModel("my-finetuned")
```

---

## 🎯 Выводы

### Главные принципы

1. **Гибкость** - EAV позволяет динамическую структуру
2. **Производительность** - Async/Await для масштабирования
3. **Модульность** - Микросервисы для независимого развития
4. **Качество** - Валидация, миграции, типизация
5. **Простота** - Docker для единообразия окружения

### Trade-offs

Каждое решение - это компромисс:

| Решение | ✅ Преимущества | ❌ Недостатки |
|---------|----------------|---------------|
| EAV | Гибкость структуры | Сложнее запросы |
| Async | Производительность | Сложнее код |
| Микросервисы | Масштабируемость | Сложнее инфраструктура |
| Pydantic | Автовалидация | Больше кода |
| Docker | Консистентность | Оверхед ресурсов |

Для **Habit Tracker** эти trade-offs оправданы, потому что:
- Гибкость важнее сырой производительности SQL
- Масштабируемость важнее простоты монолита
- Типобезопасность важнее краткости кода

---

**Архитектура = баланс между гибкостью, производительностью и поддерживаемостью** ⚖️
