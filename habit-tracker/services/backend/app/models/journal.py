# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: JournalEntry model migrated to SQLAlchemy 2.0 Mapped[]/mapped_column (mypy --strict)
from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import Date, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.core.database import Base


class JournalEntry(Base):
    """
    Journal entry model.

    Plain text notes with optional mood and tags.
    """

    __tablename__ = "journal_entries"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    title: Mapped[str | None] = mapped_column(String(200))
    content: Mapped[str] = mapped_column(Text)

    entry_date: Mapped[date] = mapped_column(Date, index=True)
    mood: Mapped[str | None] = mapped_column(String(50))  # happy, sad, neutral, ...
    tags: Mapped[str | None] = mapped_column(String(500))  # comma-separated

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self) -> str:
        return f"<JournalEntry(id={self.id}, date={self.entry_date}, title='{self.title}')>"
