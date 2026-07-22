# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: builtin generics (list[X], X | None) instead of typing.List/Optional (mypy --strict)
from datetime import date
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func

from app.models import JournalEntry
from app.schemas import JournalEntryCreate, JournalEntryUpdate


async def get_journal_entry(db: AsyncSession, entry_id: int) -> JournalEntry | None:
    """Получить дневниковую запись по ID"""
    result = await db.execute(select(JournalEntry).where(JournalEntry.id == entry_id))
    return result.scalar_one_or_none()


async def get_journal_entries(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 100,
    start_date: date | None = None,
    end_date: date | None = None,
    mood: str | None = None,
    search: str | None = None,
) -> tuple[list[JournalEntry], int]:
    """
    Получить список дневниковых записей с фильтрацией.

    Returns:
        Tuple of (entries, total_count)
    """
    # Базовый запрос
    query = select(JournalEntry)
    count_query = select(func.count()).select_from(JournalEntry)

    # Применяем фильтры
    filters = []
    if start_date:
        filters.append(JournalEntry.entry_date >= start_date)
    if end_date:
        filters.append(JournalEntry.entry_date <= end_date)
    if mood:
        filters.append(JournalEntry.mood == mood)
    if search:
        search_pattern = f"%{search}%"
        filters.append(
            or_(
                JournalEntry.title.ilike(search_pattern),
                JournalEntry.content.ilike(search_pattern),
                JournalEntry.tags.ilike(search_pattern),
            )
        )

    if filters:
        query = query.where(and_(*filters))
        count_query = count_query.where(and_(*filters))

    # Получаем общее количество
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Получаем записи с пагинацией
    query = query.offset(skip).limit(limit).order_by(JournalEntry.entry_date.desc())
    result = await db.execute(query)

    return list(result.scalars().all()), total


async def create_journal_entry(
    db: AsyncSession, entry: JournalEntryCreate
) -> JournalEntry:
    """Создать новую дневниковую запись"""
    db_entry = JournalEntry(
        title=entry.title,
        content=entry.content,
        entry_date=entry.entry_date,
        mood=entry.mood,
        tags=entry.tags,
    )
    db.add(db_entry)
    await db.commit()
    await db.refresh(db_entry)
    return db_entry


async def update_journal_entry(
    db: AsyncSession, entry_id: int, entry_update: JournalEntryUpdate
) -> JournalEntry | None:
    """Обновить дневниковую запись"""
    db_entry = await get_journal_entry(db, entry_id)
    if not db_entry:
        return None

    update_data = entry_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_entry, field, value)

    await db.commit()
    await db.refresh(db_entry)
    return db_entry


async def delete_journal_entry(db: AsyncSession, entry_id: int) -> bool:
    """Удалить дневниковую запись"""
    db_entry = await get_journal_entry(db, entry_id)
    if not db_entry:
        return False

    await db.delete(db_entry)
    await db.commit()
    return True


async def get_journal_entries_by_date(
    db: AsyncSession, entry_date: date
) -> list[JournalEntry]:
    """Получить все дневниковые записи за конкретную дату"""
    result = await db.execute(
        select(JournalEntry)
        .where(JournalEntry.entry_date == entry_date)
        .order_by(JournalEntry.created_at.desc())
    )
    return list(result.scalars().all())
