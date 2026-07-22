# [review:need-review] PHASE-01/16-checklist-upsert-today-page
# summary: added upsert_checklist_entry - one entry per (category, date), boolean values merged in place
from datetime import date
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

from app.models import Entry, EntryValue
from app.schemas import EntryCreate, EntryUpdate


async def get_entry(db: AsyncSession, entry_id: int) -> Entry | None:
    """Получить запись по ID с значениями"""
    result = await db.execute(
        select(Entry).options(selectinload(Entry.values)).where(Entry.id == entry_id)
    )
    return result.scalar_one_or_none()


async def get_entries(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 100,
    category_id: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
) -> list[Entry]:
    """
    Получить список записей с фильтрацией.

    Args:
        category_id: Фильтр по категории
        start_date: Начальная дата
        end_date: Конечная дата
    """
    query = select(Entry).options(selectinload(Entry.values))

    # Применяем фильтры
    filters = []
    if category_id:
        filters.append(Entry.category_id == category_id)
    if start_date:
        filters.append(Entry.entry_date >= start_date)
    if end_date:
        filters.append(Entry.entry_date <= end_date)

    if filters:
        query = query.where(and_(*filters))

    query = query.offset(skip).limit(limit).order_by(Entry.entry_date.desc())

    result = await db.execute(query)
    return list(result.scalars().all())


async def create_entry(db: AsyncSession, entry: EntryCreate) -> Entry:
    """
    Создать новую запись с значениями полей.
    """
    # Создаём запись
    db_entry = Entry(
        category_id=entry.category_id,
        entry_date=entry.entry_date,
        notes=entry.notes,
    )
    db.add(db_entry)
    await db.flush()  # Получаем ID записи

    # Создаём значения полей
    if entry.values:
        for value_data in entry.values:
            db_value = EntryValue(
                entry_id=db_entry.id,
                field_id=value_data.field_id,
                value=value_data.value,
            )
            db.add(db_value)

    await db.commit()
    await db.refresh(db_entry)

    # Загружаем значения
    result = await db.execute(
        select(Entry).options(selectinload(Entry.values)).where(Entry.id == db_entry.id)
    )
    return result.scalar_one()


async def update_entry(
    db: AsyncSession, entry_id: int, entry_update: EntryUpdate
) -> Entry | None:
    """
    Обновить запись.

    Если переданы новые значения (values), старые удаляются.
    """
    db_entry = await get_entry(db, entry_id)
    if not db_entry:
        return None

    # Обновляем базовые поля
    update_data = entry_update.model_dump(exclude_unset=True, exclude={"values"})
    for field, value in update_data.items():
        setattr(db_entry, field, value)

    # Обновляем значения полей, если переданы
    if entry_update.values is not None:
        # Удаляем старые значения
        for old_value in db_entry.values:
            await db.delete(old_value)
        await db.flush()

        # Создаём новые
        for value_data in entry_update.values:
            db_value = EntryValue(
                entry_id=db_entry.id,
                field_id=value_data.field_id,
                value=value_data.value,
            )
            db.add(db_value)

    await db.commit()
    await db.refresh(db_entry)

    # Загружаем значения
    result = await db.execute(
        select(Entry).options(selectinload(Entry.values)).where(Entry.id == db_entry.id)
    )
    return result.scalar_one()


async def delete_entry(db: AsyncSession, entry_id: int) -> bool:
    """Удалить запись (каскадно удаляет значения)"""
    db_entry = await get_entry(db, entry_id)
    if not db_entry:
        return False

    await db.delete(db_entry)
    await db.commit()
    return True


async def upsert_checklist_entry(
    db: AsyncSession, category_id: int, entry_date: date, values: dict[int, bool]
) -> Entry:
    """
    Идемпотентный upsert записи checklist-категории.

    Гарантирует одну запись на (category_id, entry_date): существующая
    запись переиспользуется, boolean-значения обновляются на месте
    (без дублей EntryValue при повторных вызовах).
    """
    result = await db.execute(
        select(Entry)
        .options(selectinload(Entry.values))
        .where(and_(Entry.category_id == category_id, Entry.entry_date == entry_date))
    )
    db_entry = result.scalars().first()

    if db_entry is None:
        db_entry = Entry(category_id=category_id, entry_date=entry_date)
        db.add(db_entry)
        await db.flush()
        existing_values: dict[int, EntryValue] = {}
    else:
        existing_values = {v.field_id: v for v in db_entry.values}

    for field_id, checked in values.items():
        str_value = "true" if checked else "false"
        existing = existing_values.get(field_id)
        if existing is not None:
            existing.value = str_value
        else:
            db.add(EntryValue(entry_id=db_entry.id, field_id=field_id, value=str_value))

    await db.commit()

    result = await db.execute(
        select(Entry).options(selectinload(Entry.values)).where(Entry.id == db_entry.id)
    )
    return result.scalar_one()


async def get_entries_by_date_range(
    db: AsyncSession, category_id: int, start_date: date, end_date: date
) -> list[Entry]:
    """Получить записи за период для конкретной категории"""
    result = await db.execute(
        select(Entry)
        .options(selectinload(Entry.values))
        .where(
            and_(
                Entry.category_id == category_id,
                Entry.entry_date >= start_date,
                Entry.entry_date <= end_date,
            )
        )
        .order_by(Entry.entry_date.asc())
    )
    return list(result.scalars().all())
