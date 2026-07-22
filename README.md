# 📊 Habit Tracker - Персональный трекер привычек

> Мощная альтернатива Excel для отслеживания привычек, здоровья и жизни с поддержкой AI

## 🎯 Описание проекта

Habit Tracker - это микросервисное приложение для создания персонального дашборда с динамическими категориями и полями. Вы можете создавать свои категории (витамины, сон, медитация, калории и т.д.), определять для них поля и вести записи. Все данные доступны для построения графиков и аналитики.

### ✨ Ключевые особенности

- **Динамические категории** - создавайте любые категории для отслеживания
- **Гибкие поля** - каждая категория может иметь свои уникальные поля
- **Любые типы данных** - текст, числа, даты, выбор из списка
- **Дневник** - ведите личные записи с настроением и тегами
- **API-first подход** - полностью документированный REST API
- **Готово к AI** - архитектура поддерживает добавление AI для анализа данных

---

## 🏗️ Архитектура

### Общая структура

```
habit-tracker/
├── services/
│   ├── backend/          # FastAPI микросервис (✅ ГОТОВ)
│   ├── frontend/         # Next.js приложение (📋 TODO)
│   └── ai-service/       # AI микросервис (📋 TODO)
├── docker-compose.yml    # Оркестрация сервисов
└── README.md            # Документация
```

### Технологический стек

#### Backend (Текущий MVP)
- **Python 3.10** - основной язык программирования
- **FastAPI** - современный async веб-фреймворк с автодокументацией
- **SQLAlchemy 2.0** - ORM с поддержкой async/await
- **PostgreSQL 16** - основная база данных
- **Alembic** - система миграций БД
- **Pydantic** - валидация данных и схемы
- **Uvicorn** - ASGI сервер для production

#### Frontend (Планируется)
- **Next.js 14** - React фреймворк с SSR
- **TypeScript** - типизированный JavaScript
- **TailwindCSS** - utility-first CSS фреймворк
- **Recharts** - библиотека для графиков
- **React Query** - кеширование и управление серверным состоянием

#### AI Service (Планируется)
- **OpenAI API** - GPT для анализа данных
- **Ollama** - локальные LLM модели
- **LangChain** - фреймворк для AI приложений

---

## 🗄️ Модель данных

### Почему EAV (Entity-Attribute-Value)?

Проект использует **EAV паттерн** для максимальной гибкости:

```
Традиционный подход:
sleep_table: id, date, duration, quality
vitamins_table: id, date, vitamin_name, dosage
meditation_table: id, date, duration, type

❌ Проблема: нужно создавать новую таблицу для каждой категории

EAV подход:
categories: id, name, description
fields: id, category_id, name, field_type
entries: id, category_id, entry_date
entry_values: id, entry_id, field_id, value

✅ Решение: одна структура для всех категорий
```

### Схема базы данных

```sql
┌─────────────────┐
│   categories    │  -- Категории (Сон, Витамины, etc.)
├─────────────────┤
│ id (PK)         │
│ name            │
│ description     │
│ icon            │
│ color           │
│ is_active       │
└────────┬────────┘
         │ 1
         │
         │ N
┌────────┴────────┐
│     fields      │  -- Поля категорий
├─────────────────┤
│ id (PK)         │
│ category_id(FK) │
│ name            │
│ field_type      │  -- text, number, date, select, etc.
│ is_required     │
│ options         │  -- для select типа
└────────┬────────┘
         │
         │
┌────────┴────────┐
│    entries      │  -- Записи данных
├─────────────────┤
│ id (PK)         │
│ category_id(FK) │
│ entry_date      │
│ notes           │
└────────┬────────┘
         │ 1
         │
         │ N
┌────────┴────────┐
│  entry_values   │  -- Значения полей в записях
├─────────────────┤
│ id (PK)         │
│ entry_id (FK)   │
│ field_id (FK)   │
│ value           │  -- все значения как текст
└─────────────────┘

┌─────────────────┐
│ journal_entries │  -- Дневниковые записи
├─────────────────┤
│ id (PK)         │
│ title           │
│ content         │
│ entry_date      │
│ mood            │
│ tags            │
└─────────────────┘
```

---

## 🚀 Быстрый старт

### Предварительные требования

- Docker и Docker Compose
- (Опционально) Python 3.10+ для локальной разработки

### Запуск проекта

1. **Клонируйте репозиторий**
   ```bash
   git clone <repo-url>
   cd habit-tracker
   ```

2. **Запустите сервисы через Docker Compose**
   ```bash
   docker-compose up --build
   ```

3. **Создайте миграции БД** (в отдельном терминале)
   ```bash
   docker-compose exec backend alembic revision --autogenerate -m "Initial migration"
   docker-compose exec backend alembic upgrade head
   ```

4. **Откройте документацию API**
   ```
   http://localhost:8000/docs
   ```

### Альтернативный запуск (без Docker)

```bash
cd services/backend

# Создайте виртуальное окружение
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate  # Windows

# Установите зависимости
pip install -r requirements.txt

# Запустите PostgreSQL отдельно
# Обновите .env файл с параметрами подключения

# Создайте миграции
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head

# Запустите сервер
uvicorn app.main:app --reload
```

---

## 📖 Использование API

### 1. Создание категории

Создадим категорию "Сон" с полями:

```bash
curl -X POST "http://localhost:8000/api/v1/categories" \
  -H "Content-Type: application/json" \
  -d '{
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
      },
      {
        "name": "Заметки",
        "field_type": "text",
        "is_required": false,
        "order": 3
      }
    ]
  }'
```

**Ответ:**
```json
{
  "id": 1,
  "name": "Сон",
  "description": "Отслеживание качества сна",
  "color": "#3B82F6",
  "is_active": true,
  "created_at": "2024-01-15T10:00:00",
  "updated_at": "2024-01-15T10:00:00",
  "fields": [
    {
      "id": 1,
      "name": "Продолжительность (часы)",
      "field_type": "number",
      "is_required": true,
      "order": 1,
      ...
    },
    ...
  ]
}
```

### 2. Создание записи

Добавим запись о сне:

```bash
curl -X POST "http://localhost:8000/api/v1/entries" \
  -H "Content-Type: application/json" \
  -d '{
    "category_id": 1,
    "entry_date": "2024-01-15",
    "notes": "Хорошо выспался после йоги",
    "values": [
      {"field_id": 1, "value": "8"},
      {"field_id": 2, "value": "отлично"}
    ]
  }'
```

### 3. Получение данных для графиков

```bash
# Все записи за январь для категории "Сон"
curl "http://localhost:8000/api/v1/entries/category/1/range?start_date=2024-01-01&end_date=2024-01-31"
```

### 4. Дневниковая запись

```bash
curl -X POST "http://localhost:8000/api/v1/journal" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Отличный день!",
    "content": "Сегодня был очень продуктивный день...",
    "entry_date": "2024-01-15",
    "mood": "happy",
    "tags": "работа,достижения"
  }'
```

---

## 🔧 Детали реализации

### 1. Почему FastAPI?

- **Async/Await** - высокая производительность для I/O операций
- **Автодокументация** - Swagger UI из коробки
- **Валидация** - автоматическая валидация через Pydantic
- **Типизация** - Python type hints для лучшей поддержки IDE

### 2. Почему SQLAlchemy 2.0 с Async?

```python
# Старый синхронный подход
def get_categories(db):
    return db.query(Category).all()  # Блокирует поток

# Новый async подход
async def get_categories(db: AsyncSession):
    result = await db.execute(select(Category))
    return result.scalars().all()  # Не блокирует
```

**Преимущества:**
- Может обрабатывать тысячи запросов параллельно
- Лучше использует ресурсы сервера
- Подходит для микросервисной архитектуры

### 3. Паттерн Repository (CRUD)

Вся логика работы с БД изолирована в CRUD модулях:

```python
# app/crud/category.py
async def get_category(db: AsyncSession, category_id: int):
    """Одна функция - одна ответственность"""
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.fields))
        .where(Category.id == category_id)
    )
    return result.scalar_one_or_none()
```

**Плюсы:**
- Легко тестировать
- Легко переиспользовать
- Легко поддерживать

### 4. Dependency Injection

```python
async def get_db() -> AsyncSession:
    """Автоматически управляет сессией БД"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except:
            await session.rollback()
            raise
```

FastAPI автоматически:
- Создаёт сессию перед запросом
- Закрывает её после запроса
- Откатывает транзакцию при ошибке

### 5. Миграции через Alembic

```bash
# Создать новую миграцию
alembic revision --autogenerate -m "Add mood field"

# Применить миграции
alembic upgrade head

# Откатить последнюю миграцию
alembic downgrade -1
```

**Преимущества:**
- История изменений БД в Git
- Возможность отката
- Автоматическое определение изменений

---

## 🎨 Примеры использования

### Кейс 1: Трекер витаминов

```json
{
  "name": "Витамины",
  "fields": [
    {"name": "Название", "field_type": "text"},
    {"name": "Дозировка (мг)", "field_type": "number"},
    {"name": "Время приёма", "field_type": "time"}
  ]
}
```

### Кейс 2: Трекер тренировок

```json
{
  "name": "Тренировки",
  "fields": [
    {"name": "Тип", "field_type": "select", "options": "кардио,силовая,йога"},
    {"name": "Продолжительность (мин)", "field_type": "number"},
    {"name": "Калории", "field_type": "number"},
    {"name": "Пульс средний", "field_type": "number"}
  ]
}
```

### Кейс 3: Трекер настроения

```json
{
  "name": "Настроение",
  "fields": [
    {"name": "Оценка (1-10)", "field_type": "number"},
    {"name": "Энергия", "field_type": "select", "options": "низкая,средняя,высокая"},
    {"name": "Стресс", "field_type": "select", "options": "низкий,средний,высокий"}
  ]
}
```

---

## 📊 Типы полей

| Тип | Описание | Пример значения |
|-----|----------|-----------------|
| `text` | Текстовое поле | "Отличное самочувствие" |
| `number` | Число (int/float) | "8.5" |
| `boolean` | Да/Нет | "true" или "false" |
| `date` | Дата | "2024-01-15" |
| `datetime` | Дата и время | "2024-01-15T14:30:00" |
| `time` | Время | "14:30:00" |
| `select` | Выбор из списка | "отлично" (из "плохо,средне,отлично") |

---

## 🔐 Безопасность (TODO)

В текущем MVP нет аутентификации. Для production необходимо добавить:

- [ ] JWT аутентификация
- [ ] User модель
- [ ] Rate limiting
- [ ] HTTPS
- [ ] Валидация входных данных (частично есть)

---

## 🧪 Тестирование (TODO)

```bash
# Установить тестовые зависимости
pip install pytest pytest-asyncio httpx

# Запустить тесты
pytest
```

Планируется:
- Unit тесты для CRUD операций
- Integration тесты для API endpoints
- E2E тесты

---

## 📈 Roadmap

### Phase 1: MVP Backend ✅ (ТЕКУЩАЯ СТАДИЯ)
- [x] Модели данных
- [x] CRUD операции
- [x] REST API
- [x] Docker setup
- [x] Миграции БД

### Phase 2: Frontend 📋
- [ ] Next.js приложение
- [ ] Формы создания категорий
- [ ] Дашборд с графиками
- [ ] Календарь записей
- [ ] Дневник

### Phase 3: AI Integration 📋
- [ ] OpenAI интеграция
- [ ] Анализ паттернов в данных
- [ ] Рекомендации
- [ ] Предсказания трендов

### Phase 4: Production Ready 📋
- [ ] Аутентификация и авторизация
- [ ] Тесты
- [ ] CI/CD
- [ ] Мониторинг
- [ ] Масштабирование

---

## 🤝 Вклад в проект

1. Fork проекта
2. Создайте feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit изменения (`git commit -m 'Add some AmazingFeature'`)
4. Push в branch (`git push origin feature/AmazingFeature`)
5. Создайте Pull Request

---

## 📝 Лицензия

MIT License - см. файл LICENSE

---

## 🙋 FAQ

### Q: Почему не использовать готовые решения типа Notion или Airtable?
**A:** Это даёт полный контроль над данными, возможность кастомизации под себя и интеграцию с AI без ограничений.

### Q: Почему микросервисы для такого простого проекта?
**A:** Это делает архитектуру гибкой для будущего роста. Backend, Frontend и AI сервис независимы.

### Q: Можно ли использовать другую БД вместо PostgreSQL?
**A:** Да, SQLAlchemy поддерживает MySQL, SQLite и другие. Нужно только изменить connection string.

### Q: Как масштабировать?
**A:** Каждый сервис можно масштабировать независимо. PostgreSQL можно перенести на managed решение (AWS RDS, etc.)

---

## 🔗 Полезные ссылки

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy 2.0 Documentation](https://docs.sqlalchemy.org/en/20/)
- [Alembic Documentation](https://alembic.sqlalchemy.org/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

**Создано с ❤️ для персонального трекинга привычек и данных**
