# [review:need-review] PHASE-01/16-checklist-upsert-today-page
# summary: added ChecklistUpsertRequest ({category_id, entry_date, values: {field_id: bool}})
from pydantic import BaseModel
from datetime import datetime, date


class EntryValueCreate(BaseModel):
    """Схема для создания значения поля"""

    field_id: int
    value: str | None = None


class EntryValueResponse(BaseModel):
    """Схема ответа для значения поля"""

    id: int
    entry_id: int
    field_id: int
    value: str | None

    class Config:
        from_attributes = True


class EntryBase(BaseModel):
    """Базовая схема для записи"""

    entry_date: date
    notes: str | None = None


class EntryCreate(EntryBase):
    """
    Схема для создания записи.

    values - словарь {field_id: value} или список объектов EntryValueCreate
    """

    category_id: int
    values: list[EntryValueCreate] = []


class EntryUpdate(BaseModel):
    """Схема для обновления записи"""

    entry_date: date | None = None
    notes: str | None = None
    values: list[EntryValueCreate] | None = None


class ChecklistUpsertRequest(BaseModel):
    """
    Схема идемпотентного upsert для checklist-категории.

    values — словарь {field_id: bool}: какие чек-поля выставить/снять.
    """

    category_id: int
    entry_date: date
    values: dict[int, bool]


class EntryResponse(EntryBase):
    """Схема ответа для записи"""

    id: int
    category_id: int
    created_at: datetime
    updated_at: datetime
    values: list[EntryValueResponse] = []

    class Config:
        from_attributes = True


class EntryWithCategoryResponse(EntryResponse):
    """Расширенная схема ответа с информацией о категории"""

    category_name: str
    category_color: str | None = None
