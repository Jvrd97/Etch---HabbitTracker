# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: EntryValue model migrated to SQLAlchemy 2.0 Mapped[]/mapped_column (mypy --strict)
from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.entry import Entry
    from app.models.field import Field


class EntryValue(Base):
    """
    Field value inside an entry.

    Stores the actual value for each field of an entry using the EAV
    (Entity-Attribute-Value) pattern. All values are stored as text and
    converted on read according to the field type.
    """

    __tablename__ = "entry_values"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    entry_id: Mapped[int] = mapped_column(
        ForeignKey("entries.id", ondelete="CASCADE"), index=True
    )
    field_id: Mapped[int] = mapped_column(
        ForeignKey("fields.id", ondelete="CASCADE"), index=True
    )

    value: Mapped[str | None] = mapped_column(Text)

    # Relationships
    entry: Mapped[Entry] = relationship(back_populates="values")
    field: Mapped[Field] = relationship(back_populates="entry_values")

    def __repr__(self) -> str:
        return (
            f"<EntryValue(id={self.id}, entry_id={self.entry_id}, "
            f"field_id={self.field_id}, value='{self.value}')>"
        )
