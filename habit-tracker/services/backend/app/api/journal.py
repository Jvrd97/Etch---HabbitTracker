# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: typed endpoint signatures (return annotations, builtin generics) for mypy --strict
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import journal as journal_crud
from app.models import JournalEntry
from app.schemas import (
    JournalEntryCreate,
    JournalEntryUpdate,
    JournalEntryResponse,
    JournalEntryListResponse,
)

router = APIRouter(prefix="/journal", tags=["journal"])


@router.get("/", response_model=JournalEntryListResponse)
async def get_journal_entries(
    skip: int = 0,
    limit: int = 100,
    start_date: date | None = None,
    end_date: date | None = None,
    mood: str | None = None,
    search: str | None = Query(
        None, description="Поиск по заголовку, содержанию или тегам"
    ),
    db: AsyncSession = Depends(get_db),
) -> JournalEntryListResponse:
    """
    Получить список дневниковых записей с фильтрацией и поиском.

    - **skip**: количество пропускаемых записей
    - **limit**: максимальное количество записей
    - **start_date**: начальная дата (YYYY-MM-DD)
    - **end_date**: конечная дата (YYYY-MM-DD)
    - **mood**: фильтр по настроению
    - **search**: поиск по заголовку, содержанию или тегам

    Примеры:
    - `/api/v1/journal?mood=happy` - записи с хорошим настроением
    - `/api/v1/journal?search=work` - поиск слова "work"
    - `/api/v1/journal?start_date=2024-01-01&end_date=2024-01-31` - записи за январь
    """
    entries, total = await journal_crud.get_journal_entries(
        db,
        skip=skip,
        limit=limit,
        start_date=start_date,
        end_date=end_date,
        mood=mood,
        search=search,
    )

    return JournalEntryListResponse(
        total=total,
        items=[JournalEntryResponse.model_validate(e) for e in entries],
    )


@router.get("/{entry_id}", response_model=JournalEntryResponse)
async def get_journal_entry(
    entry_id: int,
    db: AsyncSession = Depends(get_db),
) -> JournalEntry:
    """
    Получить дневниковую запись по ID.
    """
    entry = await journal_crud.get_journal_entry(db, entry_id)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Journal entry with id {entry_id} not found",
        )
    return entry


@router.post(
    "/", response_model=JournalEntryResponse, status_code=status.HTTP_201_CREATED
)
async def create_journal_entry(
    entry: JournalEntryCreate,
    db: AsyncSession = Depends(get_db),
) -> JournalEntry:
    """
    Создать новую дневниковую запись.

    Пример:
    ```json
    {
        "title": "Отличный день!",
        "content": "Сегодня был очень продуктивный день. Закончил проект...",
        "entry_date": "2024-01-15",
        "mood": "happy",
        "tags": "работа,достижения,проект"
    }
    ```

    Поддерживаемые настроения (mood):
    - happy - радостный
    - sad - грустный
    - neutral - нейтральный
    - excited - взволнованный
    - anxious - тревожный
    - calm - спокойный
    - tired - уставший

    Теги можно указывать через запятую.
    """
    return await journal_crud.create_journal_entry(db, entry)


@router.patch("/{entry_id}", response_model=JournalEntryResponse)
async def update_journal_entry(
    entry_id: int,
    entry_update: JournalEntryUpdate,
    db: AsyncSession = Depends(get_db),
) -> JournalEntry:
    """
    Обновить дневниковую запись.

    Можно обновить только нужные поля.
    """
    entry = await journal_crud.update_journal_entry(db, entry_id, entry_update)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Journal entry with id {entry_id} not found",
        )
    return entry


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_journal_entry(
    entry_id: int,
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Удалить дневниковую запись.
    """
    success = await journal_crud.delete_journal_entry(db, entry_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Journal entry with id {entry_id} not found",
        )


@router.get("/date/{entry_date}", response_model=list[JournalEntryResponse])
async def get_journal_entries_by_date(
    entry_date: date,
    db: AsyncSession = Depends(get_db),
) -> list[JournalEntry]:
    """
    Получить все дневниковые записи за конкретную дату.

    Пример: `/api/v1/journal/date/2024-01-15`
    """
    entries = await journal_crud.get_journal_entries_by_date(db, entry_date)
    return entries
