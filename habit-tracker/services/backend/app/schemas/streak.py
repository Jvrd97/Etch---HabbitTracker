# [review:need-review] PHASE-01/27-streak-mode-endpoint
# summary: StreakResponse DTO (current/best streak, last relapse date, streak mode)
from datetime import date

from pydantic import BaseModel

from app.schemas.category import CategoryStreakMode


class StreakResponse(BaseModel):
    """Streak numbers of a category, computed over its whole history."""

    category_id: int
    streak_mode: CategoryStreakMode
    current_streak: int
    best_streak: int
    last_relapse_date: date | None
