# [review:need-review] PHASE-01/35-category-fields-update-web-ux
# summary: update_category diff-syncs fields by id (update/add/delete) preserving history
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models import Category, Field
from app.models.field import FieldType
from app.schemas import CategoryCreate, CategoryUpdate, FieldCreate
from app.schemas.category import FieldUpsert


async def _sync_category_fields(
    db: AsyncSession, db_category: Category, fields: list[FieldUpsert]
) -> None:
    """
    Привести поля категории к желаемому состоянию `fields`.

    - поле с существующим id → обновляется на месте (entry_values целы);
    - поле без id (или с чужим id) → создаётся;
    - существующее поле, которого нет во входном списке → удаляется
      каскадно вместе со своей историей.
    """
    existing_by_id = {f.id: f for f in db_category.fields}
    seen_ids: set[int] = set()

    for item in fields:
        current = existing_by_id.get(item.id) if item.id is not None else None
        if current is not None:
            current.name = item.name
            current.field_type = FieldType(item.field_type)
            current.is_required = item.is_required
            current.default_value = item.default_value
            current.options = item.options
            current.order = item.order
            seen_ids.add(current.id)
        else:
            db.add(
                Field(
                    category_id=db_category.id,
                    name=item.name,
                    field_type=item.field_type,
                    is_required=item.is_required,
                    default_value=item.default_value,
                    options=item.options,
                    order=item.order,
                )
            )

    for field_id, field in existing_by_id.items():
        if field_id not in seen_ids:
            await db.delete(field)


async def get_category(db: AsyncSession, category_id: int) -> Category | None:
    """Получить категорию по ID с полями"""
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.fields))
        .where(Category.id == category_id)
    )
    return result.scalar_one_or_none()


async def get_category_by_name(db: AsyncSession, name: str) -> Category | None:
    """Получить категорию по имени"""
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.fields))
        .where(Category.name == name)
    )
    return result.scalar_one_or_none()


async def get_categories(
    db: AsyncSession, skip: int = 0, limit: int | None = 100, active_only: bool = True
) -> list[Category]:
    """Получить список категорий; limit=None отключает пагинацию"""
    query = select(Category).options(selectinload(Category.fields))

    if active_only:
        query = query.where(Category.is_active.is_(True))

    query = query.offset(skip).order_by(Category.name)
    if limit is not None:
        query = query.limit(limit)

    result = await db.execute(query)
    return list(result.scalars().all())


async def create_category(db: AsyncSession, category: CategoryCreate) -> Category:
    """
    Создать новую категорию с полями.

    Если переданы поля (fields), они создаются вместе с категорией.
    """
    # Создаём категорию
    db_category = Category(
        name=category.name,
        description=category.description,
        icon=category.icon,
        color=category.color,
        display_mode=category.display_mode,
        streak_mode=category.streak_mode,
        group=category.group,
    )
    db.add(db_category)
    await db.flush()  # Получаем ID категории

    # Создаём поля, если они переданы
    if category.fields:
        for field_data in category.fields:
            db_field = Field(
                category_id=db_category.id,
                name=field_data.name,
                field_type=field_data.field_type,
                is_required=field_data.is_required,
                default_value=field_data.default_value,
                options=field_data.options,
                order=field_data.order,
            )
            db.add(db_field)

    await db.commit()
    await db.refresh(db_category)

    # Загружаем поля
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.fields))
        .where(Category.id == db_category.id)
    )
    return result.scalar_one()


async def update_category(
    db: AsyncSession, category_id: int, category_update: CategoryUpdate
) -> Category | None:
    """
    Обновить категорию.

    Скалярные поля патчатся по exclude_unset. Если прислан `fields`, он
    трактуется как желаемое состояние набора полей и синхронизируется по id:
    существующие обновляются на месте (история сохраняется), новые создаются,
    отсутствующие удаляются. Если `fields` не прислан — поля не трогаем.
    """
    db_category = await get_category(db, category_id)
    if not db_category:
        return None

    # fields патчим отдельно: setattr на relationship списком dict сломал бы ORM.
    scalar_data = category_update.model_dump(exclude_unset=True, exclude={"fields"})
    for field, value in scalar_data.items():
        setattr(db_category, field, value)

    if category_update.fields is not None:
        await _sync_category_fields(db, db_category, category_update.fields)

    await db.commit()
    await db.refresh(db_category)

    # Загружаем поля
    result = await db.execute(
        select(Category)
        .options(selectinload(Category.fields))
        .where(Category.id == db_category.id)
    )
    return result.scalar_one()


async def delete_category(db: AsyncSession, category_id: int) -> bool:
    """Удалить категорию (каскадно удаляет поля и записи)"""
    db_category = await get_category(db, category_id)
    if not db_category:
        return False

    await db.delete(db_category)
    await db.commit()
    return True


async def add_field_to_category(
    db: AsyncSession, category_id: int, field: FieldCreate
) -> Field | None:
    """Добавить поле к категории"""
    db_category = await get_category(db, category_id)
    if not db_category:
        return None

    db_field = Field(
        category_id=category_id,
        name=field.name,
        field_type=field.field_type,
        is_required=field.is_required,
        default_value=field.default_value,
        options=field.options,
        order=field.order,
    )
    db.add(db_field)
    await db.commit()
    await db.refresh(db_field)
    return db_field
