# [review:need-review] PHASE-01/04-backend-table-endpoint
# summary: per-day aggregation for the table view (number -> sum, boolean -> any, other -> last by created_at)
import logging
from dataclasses import dataclass, field
from datetime import date, timedelta

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Entry, EntryValue, Field
from app.models.field import FieldType
from app.schemas.table import TableCell, TableDay, TableResponse

logger = logging.getLogger(__name__)

# String values treated as "true" for boolean fields (EAV stores text)
BOOLEAN_TRUE_VALUES = frozenset({"true", "1", "yes"})


@dataclass
class _CellAccumulator:
    """Mutable aggregation state for one (day, category, field) cell."""

    field_type: FieldType
    number_sum: float = 0.0
    has_number: bool = False
    any_true: bool = False
    last_value: str | None = None
    entry_ids: set[int] = field(default_factory=set)

    def add(self, entry_id: int, field_id: int, value: str | None) -> None:
        self.entry_ids.add(entry_id)
        if value is None:
            return
        if self.field_type == FieldType.NUMBER:
            try:
                self.number_sum += float(value)
                self.has_number = True
            except ValueError:
                # Non-numeric text in a number field: skip from sum.
                # The value itself is not logged (PII-safe).
                logger.warning(
                    "non-numeric value in number field",
                    extra={"field_id": field_id, "entry_id": entry_id},
                )
        elif self.field_type == FieldType.BOOLEAN:
            self.any_true = (
                self.any_true or value.strip().lower() in BOOLEAN_TRUE_VALUES
            )
        else:
            self.last_value = value  # rows arrive ordered by created_at, id

    def aggregated_value(self) -> str | None:
        if self.field_type == FieldType.NUMBER:
            if not self.has_number:
                return None
            if self.number_sum.is_integer():
                return str(int(self.number_sum))
            return str(self.number_sum)
        if self.field_type == FieldType.BOOLEAN:
            return "true" if self.any_true else "false"
        return self.last_value


async def get_table(
    db: AsyncSession,
    date_from: date,
    date_to: date,
) -> TableResponse:
    """
    Build the table view for [date_from, date_to] (inclusive).

    Every day of the range is present in the response; days without
    entries have an empty cells list. Aggregation per (category, field):
    number -> sum, boolean -> any, text/select/date/etc -> last by created_at.
    """
    result = await db.execute(
        select(
            Entry.entry_date,
            Entry.category_id,
            Entry.id,
            EntryValue.field_id,
            EntryValue.value,
            Field.field_type,
        )
        .join(EntryValue, EntryValue.entry_id == Entry.id)
        .join(Field, Field.id == EntryValue.field_id)
        .where(
            and_(
                Entry.entry_date >= date_from,
                Entry.entry_date <= date_to,
            )
        )
        .order_by(Entry.created_at.asc(), Entry.id.asc())
    )

    cells: dict[date, dict[tuple[int, int], _CellAccumulator]] = {}
    for entry_date, category_id, entry_id, field_id, value, field_type in result.all():
        day_cells = cells.setdefault(entry_date, {})
        key = (category_id, field_id)
        accumulator = day_cells.get(key)
        if accumulator is None:
            accumulator = _CellAccumulator(field_type=field_type)
            day_cells[key] = accumulator
        accumulator.add(entry_id, field_id, value)

    days: list[TableDay] = []
    current = date_from
    while current <= date_to:
        day_cells = cells.get(current, {})
        days.append(
            TableDay(
                date=current,
                cells=[
                    TableCell(
                        category_id=category_id,
                        field_id=field_id,
                        aggregated_value=accumulator.aggregated_value(),
                        entry_count=len(accumulator.entry_ids),
                    )
                    for (category_id, field_id), accumulator in sorted(
                        day_cells.items()
                    )
                ],
            )
        )
        current += timedelta(days=1)

    return TableResponse(days=days)
