# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: typed endpoint signatures (return annotations, builtin generics) for mypy --strict
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import entry as entry_crud
from app.models import Entry
from app.schemas import EntryCreate, EntryUpdate, EntryResponse

router = APIRouter(prefix="/entries", tags=["entries"])


@router.get("/", response_model=list[EntryResponse])
async def get_entries(
    skip: int = 0,
    limit: int = 100,
    category_id: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    db: AsyncSession = Depends(get_db),
) -> list[Entry]:
    """
    Получить список записей с фильтрацией.

    - **skip**: количество пропускаемых записей
    - **limit**: максимальное количество записей
    - **category_id**: фильтр по категории
    - **start_date**: начальная дата (формат: YYYY-MM-DD)
    - **end_date**: конечная дата (формат: YYYY-MM-DD)

    Примеры:
    - `/api/v1/entries?category_id=1` - все записи для категории 1
    - `/api/v1/entries?start_date=2024-01-01&end_date=2024-01-31` - записи за январь
    """
    entries = await entry_crud.get_entries(
        db,
        skip=skip,
        limit=limit,
        category_id=category_id,
        start_date=start_date,
        end_date=end_date,
    )
    return entries


@router.get("/{entry_id}", response_model=EntryResponse)
async def get_entry(
    entry_id: int,
    db: AsyncSession = Depends(get_db),
) -> Entry:
    """
    Получить запись по ID.
    """
    entry = await entry_crud.get_entry(db, entry_id)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entry with id {entry_id} not found",
        )
    return entry


@router.post("/", response_model=EntryResponse, status_code=status.HTTP_201_CREATED)
async def create_entry(
    entry: EntryCreate,
    db: AsyncSession = Depends(get_db),
) -> Entry:
    """
    Создать новую запись.

    Пример для категории "Сон" с полями "Продолжительность" и "Качество":
    ```json
    {
        "category_id": 1,
        "entry_date": "2024-01-15",
        "notes": "Хорошо выспался",
        "values": [
            {
                "field_id": 1,
                "value": "8"
            },
            {
                "field_id": 2,
                "value": "отлично"
            }
        ]
    }
    ```
    """
    return await entry_crud.create_entry(db, entry)


@router.patch("/{entry_id}", response_model=EntryResponse)
async def update_entry(
    entry_id: int,
    entry_update: EntryUpdate,
    db: AsyncSession = Depends(get_db),
) -> Entry:
    """
    Обновить запись.

    Можно обновить дату, заметки или значения полей.
    """
    entry = await entry_crud.update_entry(db, entry_id, entry_update)
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entry with id {entry_id} not found",
        )
    return entry


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_entry(
    entry_id: int,
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Удалить запись.

    Каскадно удаляет все значения полей.
    """
    success = await entry_crud.delete_entry(db, entry_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Entry with id {entry_id} not found",
        )


@router.get("/category/{category_id}/range", response_model=list[EntryResponse])
async def get_entries_by_date_range(
    category_id: int,
    start_date: date = Query(..., description="Начальная дата (YYYY-MM-DD)"),
    end_date: date = Query(..., description="Конечная дата (YYYY-MM-DD)"),
    db: AsyncSession = Depends(get_db),
) -> list[Entry]:
    """
    Получить все записи категории за указанный период.

    Полезно для построения графиков и аналитики.

    Пример: `/api/v1/entries/category/1/range?start_date=2024-01-01&end_date=2024-01-31`
    """
    entries = await entry_crud.get_entries_by_date_range(
        db, category_id, start_date, end_date
    )
    return entries
