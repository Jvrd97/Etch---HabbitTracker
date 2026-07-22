# [review:need-review] PHASE-01/25-ai-reports-history
# summary: + InsightListItem DTO (report list row with truncated content preview)
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

DEFAULT_PERIOD_DAYS = 30
MAX_PERIOD_DAYS = 366
PREVIEW_MAX_CHARS = 200


class InsightRequest(BaseModel):
    """Request body for generating an AI insight report."""

    period_days: int = Field(
        default=DEFAULT_PERIOD_DAYS,
        ge=1,
        le=MAX_PERIOD_DAYS,
        description="Number of trailing days to analyse",
    )


class InsightResponse(BaseModel):
    """Persisted AI insight report."""

    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    id: int
    period_days: int
    content: str
    model: str
    created_at: datetime


class InsightListItem(BaseModel):
    """Report list row: metadata plus a truncated content preview."""

    model_config = ConfigDict(protected_namespaces=())

    id: int
    period_days: int
    model: str
    created_at: datetime
    preview: str
