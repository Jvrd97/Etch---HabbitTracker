"""
Tests for the AI insights endpoint (POST /api/v1/insights/).
"""

# [review:need-review] PHASE-01/26-llm-cli-backend
# summary: 503 test now forces api backend explicitly (auto-detect would pick a local claude CLI)
import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.insights import get_llm_client
from app.core.config import settings
from app.llm.client import InsightsClient, LLMError
from app.llm.context import build_period_context
from app.main import app
from app.models.ai_report import AIReport


class FakeInsightsClient(InsightsClient):
    """Fake LLM client returning a canned report."""

    def __init__(self, report: str = "## Report\n\nAll good.") -> None:
        self.report = report
        self.calls: list[str] = []

    async def generate(self, context: str) -> str:
        self.calls.append(context)
        return self.report


class FailingInsightsClient(InsightsClient):
    """Fake LLM client that always fails."""

    async def generate(self, context: str) -> str:
        raise LLMError("upstream LLM error")


async def _report_count(db: AsyncSession) -> int:
    result = await db.execute(select(func.count()).select_from(AIReport))
    return result.scalar_one()


@pytest.mark.asyncio
class TestInsightsEndpoint:
    """POST /api/v1/insights/ with the LLM client mocked at the app/llm boundary."""

    async def test_returns_503_without_api_key(
        self, client: AsyncClient, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """api backend forced, empty ANTHROPIC_API_KEY -> feature off -> honest 503."""
        monkeypatch.setattr(settings, "LLM_BACKEND", "api")
        monkeypatch.setattr(settings, "ANTHROPIC_API_KEY", "")
        response = await client.post("/api/v1/insights/", json={})
        assert response.status_code == 503

    async def test_happy_path_returns_and_saves_report(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Mocked client -> 201 with content, report persisted to ai_reports."""
        fake = FakeInsightsClient(report="## Trends\n\n- more sleep")
        app.dependency_overrides[get_llm_client] = lambda: fake
        try:
            response = await client.post("/api/v1/insights/", json={"period_days": 14})
        finally:
            app.dependency_overrides.pop(get_llm_client, None)

        assert response.status_code == 201
        data = response.json()
        assert data["content"] == "## Trends\n\n- more sleep"
        assert data["period_days"] == 14
        assert data["model"]
        assert data["id"]
        assert await _report_count(db_session) == 1

    async def test_period_days_defaults_to_30(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Empty body -> period_days defaults to 30."""
        app.dependency_overrides[get_llm_client] = lambda: FakeInsightsClient()
        try:
            response = await client.post("/api/v1/insights/", json={})
        finally:
            app.dependency_overrides.pop(get_llm_client, None)

        assert response.status_code == 201
        assert response.json()["period_days"] == 30

    async def test_llm_error_returns_502_and_saves_nothing(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Client exception -> 502, no report row is written."""
        app.dependency_overrides[get_llm_client] = lambda: FailingInsightsClient()
        try:
            response = await client.post("/api/v1/insights/", json={})
        finally:
            app.dependency_overrides.pop(get_llm_client, None)

        assert response.status_code == 502
        assert await _report_count(db_session) == 0


@pytest.mark.asyncio
class TestBuildPeriodContext:
    """Unit tests for the period context builder."""

    async def test_context_includes_table_and_journal_data(
        self, client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """Context contains category/field aggregates and journal texts."""
        category_response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Sleep",
                "fields": [{"name": "Hours", "field_type": "number", "order": 1}],
            },
        )
        category = category_response.json()
        field_id = category["fields"][0]["id"]

        from datetime import date

        today = date.today().isoformat()
        entry_response = await client.post(
            "/api/v1/entries",
            json={
                "category_id": category["id"],
                "entry_date": today,
                "values": [{"field_id": field_id, "value": "7.5"}],
            },
        )
        assert entry_response.status_code == 201

        journal_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Day note",
                "content": "Slept well, felt focused",
                "entry_date": today,
                "mood": "happy",
            },
        )
        assert journal_response.status_code == 201

        context = await build_period_context(db_session, period_days=30)

        assert "Sleep" in context
        assert "Hours" in context
        assert "7.5" in context
        assert "Slept well, felt focused" in context

    async def test_context_mentions_period(self, db_session: AsyncSession) -> None:
        """Context states the requested period length."""
        context = await build_period_context(db_session, period_days=7)
        assert "7" in context
