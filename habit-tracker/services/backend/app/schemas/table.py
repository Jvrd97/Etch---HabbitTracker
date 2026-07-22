# [review:need-review] PHASE-01/17-table-groups-sport-columns
# summary: table view DTOs; added TableCategoryMeta (group, display_mode, primary field) to the response
from datetime import date

from pydantic import BaseModel

from app.schemas.category import CategoryDisplayMode


class TableCategoryMeta(BaseModel):
    """Category metadata for the table view: grouping and primary field."""

    id: int
    name: str
    display_mode: CategoryDisplayMode
    group: str | None
    primary_field_id: int | None
    primary_field_name: str | None
    primary_field_type: str | None


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

    categories: list[TableCategoryMeta]
    days: list[TableDay]
