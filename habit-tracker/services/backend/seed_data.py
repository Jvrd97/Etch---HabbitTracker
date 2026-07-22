"""
Скрипт для создания тестовых данных в БД.

Запуск:
    docker-compose exec backend python seed_data.py
"""
# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: lint/format fixes only (stray f-prefix removed, ruff format)

import asyncio
from datetime import date, timedelta
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import AsyncSessionLocal
from app.models import Category, Field, Entry, EntryValue, JournalEntry, FieldType


async def clear_all_data(db: AsyncSession):
    """Очистить все данные из БД"""
    print("🗑️  Очистка старых данных...")

    # Удаляем в правильном порядке (из-за foreign keys)
    await db.execute("DELETE FROM entry_values")
    await db.execute("DELETE FROM entries")
    await db.execute("DELETE FROM fields")
    await db.execute("DELETE FROM categories")
    await db.execute("DELETE FROM journal_entries")

    await db.commit()
    print("✅ Старые данные удалены")


async def seed_categories(db: AsyncSession):
    """Создать тестовые категории с полями"""
    print("\n📊 Создание категорий...")

    categories_data = [
        {
            "name": "Сон",
            "description": "Отслеживание качества и продолжительности сна",
            "color": "#3B82F6",
            "icon": "🌙",
            "fields": [
                {
                    "name": "Продолжительность (часы)",
                    "field_type": FieldType.NUMBER,
                    "is_required": True,
                    "order": 1,
                },
                {
                    "name": "Качество",
                    "field_type": FieldType.SELECT,
                    "options": "плохо,средне,отлично",
                    "order": 2,
                },
                {
                    "name": "Время отхода ко сну",
                    "field_type": FieldType.TIME,
                    "order": 3,
                },
                {
                    "name": "Сон был глубоким",
                    "field_type": FieldType.BOOLEAN,
                    "order": 4,
                },
            ],
        },
        {
            "name": "Тренировки",
            "description": "Физическая активность",
            "color": "#EF4444",
            "icon": "💪",
            "fields": [
                {
                    "name": "Тип тренировки",
                    "field_type": FieldType.SELECT,
                    "options": "кардио,силовая,йога,плавание,бег",
                    "is_required": True,
                    "order": 1,
                },
                {
                    "name": "Продолжительность (минуты)",
                    "field_type": FieldType.NUMBER,
                    "is_required": True,
                    "order": 2,
                },
                {"name": "Калории", "field_type": FieldType.NUMBER, "order": 3},
                {
                    "name": "Интенсивность (1-10)",
                    "field_type": FieldType.NUMBER,
                    "order": 4,
                },
                {"name": "Средний пульс", "field_type": FieldType.NUMBER, "order": 5},
            ],
        },
        {
            "name": "Питание",
            "description": "Дневной рацион и калории",
            "color": "#10B981",
            "icon": "🥗",
            "fields": [
                {
                    "name": "Калории",
                    "field_type": FieldType.NUMBER,
                    "is_required": True,
                    "order": 1,
                },
                {"name": "Белки (г)", "field_type": FieldType.NUMBER, "order": 2},
                {"name": "Углеводы (г)", "field_type": FieldType.NUMBER, "order": 3},
                {"name": "Жиры (г)", "field_type": FieldType.NUMBER, "order": 4},
                {"name": "Вода (мл)", "field_type": FieldType.NUMBER, "order": 5},
                {"name": "Соблюдал диету", "field_type": FieldType.BOOLEAN, "order": 6},
            ],
        },
        {
            "name": "Настроение",
            "description": "Эмоциональное состояние",
            "color": "#F59E0B",
            "icon": "😊",
            "fields": [
                {
                    "name": "Оценка настроения (1-10)",
                    "field_type": FieldType.NUMBER,
                    "is_required": True,
                    "order": 1,
                },
                {
                    "name": "Уровень энергии",
                    "field_type": FieldType.SELECT,
                    "options": "низкий,средний,высокий",
                    "order": 2,
                },
                {
                    "name": "Уровень стресса",
                    "field_type": FieldType.SELECT,
                    "options": "низкий,средний,высокий",
                    "order": 3,
                },
                {
                    "name": "Медитация (минуты)",
                    "field_type": FieldType.NUMBER,
                    "order": 4,
                },
            ],
        },
        {
            "name": "Витамины",
            "description": "Приём витаминов и добавок",
            "color": "#8B5CF6",
            "icon": "💊",
            "fields": [
                {
                    "name": "Название",
                    "field_type": FieldType.TEXT,
                    "is_required": True,
                    "order": 1,
                },
                {"name": "Дозировка (мг)", "field_type": FieldType.NUMBER, "order": 2},
                {"name": "Время приёма", "field_type": FieldType.TIME, "order": 3},
                {
                    "name": "Принял",
                    "field_type": FieldType.BOOLEAN,
                    "is_required": True,
                    "order": 4,
                },
            ],
        },
    ]

    created_categories = []

    for cat_data in categories_data:
        fields_data = cat_data.pop("fields")

        # Создаём категорию
        category = Category(**cat_data)
        db.add(category)
        await db.flush()

        # Создаём поля
        for field_data in fields_data:
            field = Field(category_id=category.id, **field_data)
            db.add(field)

        created_categories.append(category)
        print(f"  ✅ {category.name}")

    await db.commit()
    print(f"\n✅ Создано {len(created_categories)} категорий")

    return created_categories


async def seed_entries(db: AsyncSession, categories: list[Category]):
    """Создать тестовые записи за последние 30 дней"""
    print("\n📝 Создание записей за последние 30 дней...")

    today = date.today()
    total_entries = 0

    for category in categories:
        # Загружаем поля категории
        await db.refresh(category, ["fields"])

        # Создаём записи за каждый день
        for days_ago in range(30):
            entry_date = today - timedelta(days=days_ago)

            entry = Entry(
                category_id=category.id,
                entry_date=entry_date,
                notes="Автоматически созданная запись для тестирования",
            )
            db.add(entry)
            await db.flush()

            # Создаём значения для каждого поля
            for field in category.fields:
                value = generate_test_value(field, days_ago)

                entry_value = EntryValue(
                    entry_id=entry.id, field_id=field.id, value=value
                )
                db.add(entry_value)

            total_entries += 1

    await db.commit()
    print(f"✅ Создано {total_entries} записей")


def generate_test_value(field: Field, days_ago: int) -> str:
    """Генерировать реалистичное тестовое значение"""
    import random

    if field.field_type == FieldType.NUMBER:
        # Генерируем числа с небольшой вариацией
        if "часы" in field.name.lower() or "продолжительность" in field.name.lower():
            if "сон" in field.name.lower():
                return str(random.uniform(6.5, 9.0))  # Часы сна
            else:
                return str(random.randint(30, 90))  # Минуты тренировки
        elif "калор" in field.name.lower():
            return str(random.randint(1800, 2500))
        elif "пульс" in field.name.lower():
            return str(random.randint(120, 160))
        elif (
            "настроение" in field.name.lower() or "интенсивность" in field.name.lower()
        ):
            return str(random.randint(6, 9))
        elif "белки" in field.name.lower():
            return str(random.randint(80, 150))
        elif "углеводы" in field.name.lower():
            return str(random.randint(200, 350))
        elif "жиры" in field.name.lower():
            return str(random.randint(50, 90))
        elif "вода" in field.name.lower():
            return str(random.randint(1500, 3000))
        elif "дозировка" in field.name.lower():
            return str(random.choice([500, 1000, 2000]))
        else:
            return str(random.randint(1, 100))

    elif field.field_type == FieldType.SELECT:
        options = field.options.split(",") if field.options else ["option1", "option2"]
        return random.choice(options)

    elif field.field_type == FieldType.BOOLEAN:
        return str(random.choice([True, False])).lower()

    elif field.field_type == FieldType.TIME:
        hour = (
            random.randint(21, 23)
            if "отход" in field.name.lower()
            else random.randint(8, 12)
        )
        minute = random.randint(0, 59)
        return f"{hour:02d}:{minute:02d}:00"

    elif field.field_type == FieldType.TEXT:
        vitamins = ["Витамин D", "Витамин C", "Омега-3", "Магний", "Цинк"]
        return random.choice(vitamins)

    else:
        return "test value"


async def seed_journal_entries(db: AsyncSession):
    """Создать тестовые дневниковые записи"""
    print("\n📖 Создание дневниковых записей...")

    today = date.today()

    journal_data = [
        {
            "title": "Отличный день!",
            "content": "Сегодня был очень продуктивный день. Закончил важный проект, сходил на тренировку и хорошо поспал. Чувствую себя отлично!",
            "mood": "happy",
            "tags": "работа,достижения,тренировка",
            "entry_date": today - timedelta(days=1),
        },
        {
            "title": "Размышления о здоровье",
            "content": "Начал обращать больше внимания на качество сна. Заметил, что когда сплю 8+ часов, энергии значительно больше.",
            "mood": "calm",
            "tags": "здоровье,сон,наблюдения",
            "entry_date": today - timedelta(days=3),
        },
        {
            "title": "Новая цель",
            "content": "Решил начать медитировать каждый день хотя бы по 10 минут. Говорят, это помогает со стрессом.",
            "mood": "excited",
            "tags": "цели,медитация,саморазвитие",
            "entry_date": today - timedelta(days=5),
        },
        {
            "title": "Трудный день",
            "content": "Было много стресса на работе. Но тренировка вечером помогла разгрузиться. Важно не забывать о физической активности даже в загруженные дни.",
            "mood": "tired",
            "tags": "работа,стресс,тренировка",
            "entry_date": today - timedelta(days=7),
        },
        {
            "title": "Прогресс!",
            "content": "Уже неделю веду трекинг привычек. Начинаю замечать паттерны - когда хорошо сплю, настроение лучше и больше энергии для тренировок.",
            "mood": "happy",
            "tags": "прогресс,наблюдения,мотивация",
            "entry_date": today - timedelta(days=10),
        },
    ]

    for data in journal_data:
        entry = JournalEntry(**data)
        db.add(entry)

    await db.commit()
    print(f"✅ Создано {len(journal_data)} дневниковых записей")


async def main():
    """Главная функция"""
    print("=" * 60)
    print("🌱 SEED DATA SCRIPT")
    print("=" * 60)

    async with AsyncSessionLocal() as db:
        try:
            # Очищаем старые данные
            await clear_all_data(db)

            # Создаём категории с полями
            categories = await seed_categories(db)

            # Создаём записи
            await seed_entries(db, categories)

            # Создаём дневниковые записи
            await seed_journal_entries(db)

            print("\n" + "=" * 60)
            print("✅ ВСЕ ТЕСТОВЫЕ ДАННЫЕ СОЗДАНЫ!")
            print("=" * 60)
            print("\n📊 Теперь можно:")
            print("  1. Открыть http://localhost:8000/docs")
            print("  2. Попробовать GET /api/v1/categories")
            print("  3. Посмотреть GET /api/v1/entries")
            print("  4. Изучить GET /api/v1/journal")
            print("\n🎉 Готово к тестированию!")

        except Exception as e:
            print(f"\n❌ Ошибка: {e}")
            raise


if __name__ == "__main__":
    asyncio.run(main())
