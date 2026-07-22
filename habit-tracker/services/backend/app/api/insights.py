# [review:need-review] PHASE-01/26-llm-cli-backend
# summary: POST /api/v1/insights — backend selection moved to resolve_insights_client (cli/api)
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import insight as insight_crud
from app.llm.client import InsightsClient, LLMError, resolve_insights_client
from app.llm.context import build_period_context
from app.models import AIReport
from app.schemas import InsightRequest, InsightResponse

router = APIRouter(prefix="/insights", tags=["insights"])


def get_llm_client() -> InsightsClient | None:
    """
    LLM client dependency; None when no backend is available.

    Tests override this dependency to mock at the app/llm boundary.
    """
    return resolve_insights_client()


@router.post("/", response_model=InsightResponse, status_code=status.HTTP_201_CREATED)
async def create_insight(
    payload: InsightRequest | None = None,
    db: AsyncSession = Depends(get_db),
    llm: InsightsClient | None = Depends(get_llm_client),
) -> AIReport:
    """
    Сгенерировать AI-разбор периода и сохранить отчёт.

    - **period_days**: длина периода в днях (по умолчанию 30)

    Синхронный вызов LLM с щедрым таймаутом. Бэкенд выбирается через
    LLM_BACKEND (cli | api | auto); если ни один недоступен — 503;
    при ошибке LLM — 502 (отчёт в этом случае не сохраняется).
    """
    if llm is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "AI insights are disabled: no LLM backend available "
                "(set ANTHROPIC_API_KEY or install the claude CLI)"
            ),
        )

    request = payload if payload is not None else InsightRequest()
    context = await build_period_context(db, period_days=request.period_days)

    try:
        content = await llm.generate(context)
    except LLMError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="LLM request failed",
        ) from exc

    return await insight_crud.create_ai_report(
        db,
        period_days=request.period_days,
        content=content,
        model=llm.model,
    )
