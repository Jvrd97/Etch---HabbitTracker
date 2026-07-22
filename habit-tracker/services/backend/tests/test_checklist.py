"""
Tests for checklist entry upsert (PUT /api/v1/entries/checklist).
"""

# [review:need-review] PHASE-01/16-checklist-upsert-today-page
# summary: idempotent checklist upsert - create, update same row, uncheck, 422 on form category
import pytest
from httpx import AsyncClient

ENTRY_DATE = "2026-07-20"


@pytest.fixture
async def checklist_category(client: AsyncClient) -> dict:
    """Checklist category (Vitamins) with two boolean fields."""
    response = await client.post(
        "/api/v1/categories",
        json={
            "name": "Vitamins",
            "display_mode": "checklist",
            "fields": [
                {"name": "B12", "field_type": "boolean", "order": 1},
                {"name": "D3", "field_type": "boolean", "order": 2},
            ],
        },
    )
    assert response.status_code == 201
    return response.json()


@pytest.fixture
async def form_category(client: AsyncClient) -> dict:
    """Regular form category (Sport) with a number field."""
    response = await client.post(
        "/api/v1/categories",
        json={
            "name": "Sport",
            "display_mode": "form",
            "fields": [{"name": "Pushups", "field_type": "number", "order": 1}],
        },
    )
    assert response.status_code == 201
    return response.json()


def field_id_by_name(category: dict, name: str) -> int:
    return next(f["id"] for f in category["fields"] if f["name"] == name)


@pytest.mark.asyncio
class TestChecklistUpsert:
    """Tests for the idempotent checklist upsert endpoint."""

    async def test_first_put_creates_entry(
        self, client: AsyncClient, checklist_category: dict
    ):
        """First PUT creates a new entry with boolean values."""
        b12 = field_id_by_name(checklist_category, "B12")

        response = await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": checklist_category["id"],
                "entry_date": ENTRY_DATE,
                "values": {str(b12): True},
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["category_id"] == checklist_category["id"]
        assert data["entry_date"] == ENTRY_DATE
        values = {v["field_id"]: v["value"] for v in data["values"]}
        assert values[b12] == "true"

    async def test_second_put_updates_same_entry(
        self, client: AsyncClient, checklist_category: dict
    ):
        """Second PUT for the same (category, date) updates the same row: count stays 1."""
        b12 = field_id_by_name(checklist_category, "B12")
        d3 = field_id_by_name(checklist_category, "D3")

        first = await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": checklist_category["id"],
                "entry_date": ENTRY_DATE,
                "values": {str(b12): True},
            },
        )
        second = await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": checklist_category["id"],
                "entry_date": ENTRY_DATE,
                "values": {str(d3): True},
            },
        )
        assert second.status_code == 200
        assert second.json()["id"] == first.json()["id"]

        listing = await client.get(
            f"/api/v1/entries?category_id={checklist_category['id']}"
        )
        entries = listing.json()
        assert len(entries) == 1
        values = {v["field_id"]: v["value"] for v in entries[0]["values"]}
        assert values[b12] == "true"
        assert values[d3] == "true"

    async def test_uncheck_sets_value_false(
        self, client: AsyncClient, checklist_category: dict
    ):
        """Unchecking (value false) updates the existing value, no duplicate rows."""
        b12 = field_id_by_name(checklist_category, "B12")

        await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": checklist_category["id"],
                "entry_date": ENTRY_DATE,
                "values": {str(b12): True},
            },
        )
        response = await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": checklist_category["id"],
                "entry_date": ENTRY_DATE,
                "values": {str(b12): False},
            },
        )
        assert response.status_code == 200
        data = response.json()
        b12_values = [v for v in data["values"] if v["field_id"] == b12]
        assert len(b12_values) == 1
        assert b12_values[0]["value"] == "false"

    async def test_put_to_form_category_returns_422(
        self, client: AsyncClient, form_category: dict
    ):
        """PUT to a non-checklist category is rejected with 422."""
        field_id = form_category["fields"][0]["id"]

        response = await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": form_category["id"],
                "entry_date": ENTRY_DATE,
                "values": {str(field_id): True},
            },
        )
        assert response.status_code == 422

    async def test_put_to_unknown_category_returns_404(self, client: AsyncClient):
        """PUT to a nonexistent category returns 404."""
        response = await client.put(
            "/api/v1/entries/checklist",
            json={
                "category_id": 99999,
                "entry_date": ENTRY_DATE,
                "values": {"1": True},
            },
        )
        assert response.status_code == 404
