# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: Field model migrated to SQLAlchemy 2.0 Mapped[]/mapped_column (mypy --strict)
from __future__ import annotations

import enum
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.category import Category
    from app.models.entry_value import EntryValue


class FieldType(str, enum.Enum):
    """Field types a user can create."""

    TEXT = "text"
    NUMBER = "number"
    BOOLEAN = "boolean"
    DATE = "date"
    DATETIME = "datetime"
    TIME = "time"
    SELECT = "select"


class Field(Base):
    """
    Category field model.

    Defines which fields are available for entries of a category.
    For example, a "Sleep" category may have fields:
    - duration (number)
    - quality (select)
    - notes (text)
    """

    __tablename__ = "fields"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id", ondelete="CASCADE")
    )

    name: Mapped[str] = mapped_column(String(100))
    field_type: Mapped[FieldType] = mapped_column(Enum(FieldType))
    is_required: Mapped[bool] = mapped_column(default=False)
    default_value: Mapped[str | None] = mapped_column(String(255))
    options: Mapped[str | None] = mapped_column(String(500))  # JSON string for select

    order: Mapped[int] = mapped_column(default=0)  # Display order

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    category: Mapped[Category] = relationship(back_populates="fields")
    entry_values: Mapped[list[EntryValue]] = relationship(
        back_populates="field", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Field(id={self.id}, name='{self.name}', type='{self.field_type}')>"
