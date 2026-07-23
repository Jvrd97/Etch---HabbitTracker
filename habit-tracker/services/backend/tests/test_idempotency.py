"""
Tests for POST /entries idempotency key (Idempotency-Key header).

Closes the offline-queue duplicate window: a replayed create with the same
key must return the original entry instead of creating a second one.
"""

# [review:need-review] PHASE-01/39-server-idempotency-key-entries
# summary: POST /entries Idempotency-Key - replay with same key returns original (200) no dup, distinct keys create separate entries, no header still creates every time
import pytest
from httpx import AsyncClient


@pytest.fixture
async def sample_category(client: AsyncClient) -> dict:
    """Create a sample category with a single numeric field."""
    response = await client.post(
        "/api/v1/categories",
        json={
            "name": "Sleep",
            "description": "Track sleep quality",
            "fields": [
                {
                    "name": "Duration (hours)",
                    "field_type": "number",
                    "is_required": True,
                    "order": 1,
                },
            ],
        },
    )
    return response.json()


def _entry_payload(category: dict) -> dict:
    field_id = category["fields"][0]["id"]
    return {
        "category_id": category["id"],
        "entry_date": "2024-01-15",
        "notes": "Good night sleep",
        "values": [{"field_id": field_id, "value": "8"}],
    }


@pytest.mark.asyncio
class TestEntryIdempotency:
    """Idempotency-Key on POST /entries."""

    async def test_repeat_with_same_key_returns_original_no_duplicate(
        self, client: AsyncClient, sample_category: dict
    ) -> None:
        """Replaying a create with the same key returns the original entry."""
        payload = _entry_payload(sample_category)
        headers = {"Idempotency-Key": "pending-entry-uuid-1"}

        first = await client.post("/api/v1/entries", json=payload, headers=headers)
        assert first.status_code == 201
        first_id = first.json()["id"]

        second = await client.post("/api/v1/entries", json=payload, headers=headers)
        assert second.status_code == 200
        assert second.json()["id"] == first_id

        listing = await client.get(
            f"/api/v1/entries?category_id={sample_category['id']}"
        )
        assert len([e for e in listing.json() if e["id"] == first_id]) == 1
        assert len(listing.json()) == 1

    async def test_different_keys_create_separate_entries(
        self, client: AsyncClient, sample_category: dict
    ) -> None:
        """Distinct idempotency keys create distinct entries."""
        payload = _entry_payload(sample_category)

        first = await client.post(
            "/api/v1/entries", json=payload, headers={"Idempotency-Key": "key-a"}
        )
        second = await client.post(
            "/api/v1/entries", json=payload, headers={"Idempotency-Key": "key-b"}
        )

        assert first.status_code == 201
        assert second.status_code == 201
        assert first.json()["id"] != second.json()["id"]

        listing = await client.get(
            f"/api/v1/entries?category_id={sample_category['id']}"
        )
        assert len(listing.json()) == 2

    async def test_post_without_key_still_creates(
        self, client: AsyncClient, sample_category: dict
    ) -> None:
        """Backward compatibility: no header means plain create, every time."""
        payload = _entry_payload(sample_category)

        first = await client.post("/api/v1/entries", json=payload)
        second = await client.post("/api/v1/entries", json=payload)

        assert first.status_code == 201
        assert second.status_code == 201
        assert first.json()["id"] != second.json()["id"]
