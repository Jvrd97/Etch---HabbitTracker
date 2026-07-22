# [review:need-review] PHASE-01/15-category-display-mode-group
# summary: added display_mode (Literal form|checklist) and group to category schemas
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Literal

CategoryDisplayMode = Literal["form", "checklist"]


class FieldBase(BaseModel):
    """Базовая схема для поля"""

    name: str = Field(..., min_length=1, max_length=100)
    field_type: str = Field(
        ..., description="Тип поля: text, number, boolean, date, datetime, time, select"
    )
    is_required: bool = False
    default_value: str | None = None
    options: str | None = None  # JSON строка для select типа
    order: int = 0


class FieldCreate(FieldBase):
    """Схема для создания поля"""

    pass


class FieldUpdate(BaseModel):
    """Схема для обновления поля"""

    name: str | None = Field(None, min_length=1, max_length=100)
    field_type: str | None = None
    is_required: bool | None = None
    default_value: str | None = None
    options: str | None = None
    order: int | None = None


class FieldResponse(FieldBase):
    """Схема ответа для поля"""

    id: int
    category_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CategoryBase(BaseModel):
    """Базовая схема для категории"""

    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = None
    icon: str | None = Field(None, max_length=50)
    color: str | None = Field(None, max_length=7, pattern=r"^#[0-9A-Fa-f]{6}$")
    display_mode: CategoryDisplayMode = "form"
    group: str | None = Field(None, max_length=100)


class CategoryCreate(CategoryBase):
    """
    Схема для создания категории.
    Поля создаются отдельно или вместе с категорией.
    """

    fields: list[FieldCreate] | None = []


class CategoryUpdate(BaseModel):
    """Схема для обновления категории"""

    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = None
    icon: str | None = Field(None, max_length=50)
    color: str | None = Field(None, max_length=7, pattern=r"^#[0-9A-Fa-f]{6}$")
    is_active: bool | None = None
    display_mode: CategoryDisplayMode | None = None
    group: str | None = Field(None, max_length=100)


class CategoryResponse(CategoryBase):
    """Схема ответа для категории"""

    id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    fields: list[FieldResponse] = []

    class Config:
        from_attributes = True
