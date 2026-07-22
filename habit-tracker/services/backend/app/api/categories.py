# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: typed endpoint signatures (return annotations, builtin generics) for mypy --strict
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import category as category_crud
from app.models import Category, Field
from app.schemas import (
    CategoryCreate,
    CategoryUpdate,
    CategoryResponse,
    FieldCreate,
    FieldResponse,
)

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("/", response_model=list[CategoryResponse])
async def get_categories(
    skip: int = 0,
    limit: int = 100,
    active_only: bool = True,
    db: AsyncSession = Depends(get_db),
) -> list[Category]:
    """
    Получить список всех категорий.

    - **skip**: количество пропускаемых записей (для пагинации)
    - **limit**: максимальное количество возвращаемых записей
    - **active_only**: показывать только активные категории
    """
    categories = await category_crud.get_categories(
        db, skip=skip, limit=limit, active_only=active_only
    )
    return categories


@router.get("/{category_id}", response_model=CategoryResponse)
async def get_category(
    category_id: int,
    db: AsyncSession = Depends(get_db),
) -> Category:
    """
    Получить категорию по ID.
    """
    category = await category_crud.get_category(db, category_id)
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Category with id {category_id} not found",
        )
    return category


@router.post("/", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
async def create_category(
    category: CategoryCreate,
    db: AsyncSession = Depends(get_db),
) -> Category:
    """
    Создать новую категорию.

    Можно сразу добавить поля через параметр `fields`.

    Пример:
    ```json
    {
        "name": "Сон",
        "description": "Отслеживание качества сна",
        "color": "#3B82F6",
        "fields": [
            {
                "name": "Продолжительность",
                "field_type": "number",
                "is_required": true
            },
            {
                "name": "Качество",
                "field_type": "select",
                "options": "плохо,средне,отлично"
            }
        ]
    }
    ```
    """
    # Проверяем, не существует ли уже категория с таким именем
    existing = await category_crud.get_category_by_name(db, category.name)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Category with name '{category.name}' already exists",
        )

    return await category_crud.create_category(db, category)


@router.patch("/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: int,
    category_update: CategoryUpdate,
    db: AsyncSession = Depends(get_db),
) -> Category:
    """
    Обновить категорию.

    Можно обновить только нужные поля.
    """
    category = await category_crud.update_category(db, category_id, category_update)
    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Category with id {category_id} not found",
        )
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(
    category_id: int,
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Удалить категорию.

    ⚠️ ВНИМАНИЕ: Это каскадно удалит все поля и записи этой категории!
    """
    success = await category_crud.delete_category(db, category_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Category with id {category_id} not found",
        )


@router.post(
    "/{category_id}/fields",
    response_model=FieldResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_field_to_category(
    category_id: int,
    field: FieldCreate,
    db: AsyncSession = Depends(get_db),
) -> Field:
    """
    Добавить новое поле к существующей категории.

    Пример:
    ```json
    {
        "name": "Заметки",
        "field_type": "text",
        "is_required": false
    }
    ```
    """
    db_field = await category_crud.add_field_to_category(db, category_id, field)
    if not db_field:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Category with id {category_id} not found",
        )
    return db_field
