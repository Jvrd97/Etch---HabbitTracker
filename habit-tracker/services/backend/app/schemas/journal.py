# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: builtin generics (list[X], X | None) instead of typing.List/Optional (mypy --strict)
from pydantic import BaseModel, Field
from datetime import datetime, date


class JournalEntryBase(BaseModel):
    """Базовая схема для дневниковой записи"""

    title: str | None = Field(None, max_length=200)
    content: str = Field(..., min_length=1)
    entry_date: date
    mood: str | None = Field(None, max_length=50)
    tags: str | None = Field(None, max_length=500)


class JournalEntryCreate(JournalEntryBase):
    """Схема для создания дневниковой записи"""

    pass


class JournalEntryUpdate(BaseModel):
    """Схема для обновления дневниковой записи"""

    title: str | None = Field(None, max_length=200)
    content: str | None = Field(None, min_length=1)
    entry_date: date | None = None
    mood: str | None = Field(None, max_length=50)
    tags: str | None = Field(None, max_length=500)


class JournalEntryResponse(JournalEntryBase):
    """Схема ответа для дневниковой записи"""

    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class JournalEntryListResponse(BaseModel):
    """Схема ответа для списка дневниковых записей"""

    total: int
    items: list[JournalEntryResponse]
