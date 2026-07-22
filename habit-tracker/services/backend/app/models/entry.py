# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: Entry model migrated to SQLAlchemy 2.0 Mapped[]/mapped_column (mypy --strict)
from __future__ import annotations

from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.category import Category
    from app.models.entry_value import EntryValue


class Entry(Base):
    """
    Category entry model.

    One data record for a category, e.g. one sleep record for a date.
    """

    __tablename__ = "entries"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id", ondelete="CASCADE"), index=True
    )

    entry_date: Mapped[date] = mapped_column(Date, index=True)
    notes: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    category: Mapped[Category] = relationship(back_populates="entries")
    values: Mapped[list[EntryValue]] = relationship(
        back_populates="entry", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Entry(id={self.id}, category_id={self.category_id}, date={self.entry_date})>"
