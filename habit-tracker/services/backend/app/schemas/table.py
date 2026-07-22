# [review:need-review] PHASE-01/04-backend-table-endpoint
# summary: Pydantic DTOs for the table view response (days -> cells with aggregated values)
from datetime import date

from pydantic import BaseModel


class TableCell(BaseModel):
    """Aggregated value of one field for one day."""

    category_id: int
    field_id: int
    aggregated_value: str | None
    entry_count: int


class TableDay(BaseModel):
    """One day of the table with aggregated cells."""

    date: date
    cells: list[TableCell]


class TableResponse(BaseModel):
    """Table view over a date range."""

    days: list[TableDay]
