"""
Tests for Journal Entry CRUD operations.
"""

import pytest
from httpx import AsyncClient
from datetime import date


@pytest.mark.asyncio
class TestJournalCreate:
    """Tests for creating journal entries."""

    async def test_create_journal_entry(self, client: AsyncClient):
        """Test creating a basic journal entry."""
        response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Great Day!",
                "content": "Today was very productive. Finished the project.",
                "entry_date": "2024-01-15",
                "mood": "happy",
                "tags": "work,productivity",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["title"] == "Great Day!"
        assert data["content"] == "Today was very productive. Finished the project."
        assert data["entry_date"] == "2024-01-15"
        assert data["mood"] == "happy"
        assert data["tags"] == "work,productivity"
        assert "id" in data

    async def test_create_journal_entry_without_tags(self, client: AsyncClient):
        """Test creating journal entry without tags."""
        response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Simple Entry",
                "content": "Just a regular day.",
                "entry_date": "2024-01-15",
                "mood": "neutral",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["tags"] is None or data["tags"] == ""

    async def test_create_journal_entry_with_current_date(self, client: AsyncClient):
        """Test creating journal entry with today's date."""
        today = date.today().isoformat()

        response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Today",
                "content": "Today's entry",
                "entry_date": today,
                "mood": "happy",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["entry_date"] == today

    async def test_create_journal_entry_all_moods(self, client: AsyncClient):
        """Test creating journal entries with different moods."""
        moods = ["happy", "sad", "neutral", "excited", "anxious", "calm", "tired"]

        for mood in moods:
            response = await client.post(
                "/api/v1/journal",
                json={
                    "title": f"{mood.capitalize()} Day",
                    "content": f"Feeling {mood} today",
                    "entry_date": "2024-01-15",
                    "mood": mood,
                },
            )
            assert response.status_code == 201
            data = response.json()
            assert data["mood"] == mood


@pytest.mark.asyncio
class TestJournalRead:
    """Tests for reading journal entries."""

    async def test_get_all_journal_entries(self, client: AsyncClient):
        """Test getting all journal entries."""
        # Create multiple entries
        for i in range(3):
            await client.post(
                "/api/v1/journal",
                json={
                    "title": f"Entry {i + 1}",
                    "content": f"Content {i + 1}",
                    "entry_date": f"2024-01-{15 + i:02d}",
                    "mood": "happy",
                },
            )

        response = await client.get("/api/v1/journal")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 3
        assert len(data["items"]) == 3

    async def test_get_journal_entry_by_id(self, client: AsyncClient):
        """Test getting specific journal entry by ID."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Test Entry",
                "content": "Test content",
                "entry_date": "2024-01-15",
                "mood": "happy",
            },
        )
        entry_id = create_response.json()["id"]

        # Get entry
        response = await client.get(f"/api/v1/journal/{entry_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == entry_id
        assert data["title"] == "Test Entry"

    async def test_get_nonexistent_journal_entry(self, client: AsyncClient):
        """Test getting nonexistent journal entry returns 404."""
        response = await client.get("/api/v1/journal/9999")
        assert response.status_code == 404

    async def test_get_journal_entries_by_date(self, client: AsyncClient):
        """Test getting journal entries for a specific date."""
        # Create entries on different dates
        await client.post(
            "/api/v1/journal",
            json={
                "title": "Jan 15 Entry 1",
                "content": "First entry",
                "entry_date": "2024-01-15",
                "mood": "happy",
            },
        )
        await client.post(
            "/api/v1/journal",
            json={
                "title": "Jan 15 Entry 2",
                "content": "Second entry",
                "entry_date": "2024-01-15",
                "mood": "neutral",
            },
        )
        await client.post(
            "/api/v1/journal",
            json={
                "title": "Jan 16 Entry",
                "content": "Different date",
                "entry_date": "2024-01-16",
                "mood": "happy",
            },
        )

        # Get entries for Jan 15
        response = await client.get("/api/v1/journal/date/2024-01-15")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        for entry in data:
            assert entry["entry_date"] == "2024-01-15"

    async def test_filter_journal_entries_by_date_range(self, client: AsyncClient):
        """Test filtering journal entries by date range."""
        dates = ["2024-01-10", "2024-01-15", "2024-01-20", "2024-01-25"]
        for entry_date in dates:
            await client.post(
                "/api/v1/journal",
                json={
                    "title": f"Entry {entry_date}",
                    "content": "Content",
                    "entry_date": entry_date,
                    "mood": "happy",
                },
            )

        response = await client.get(
            "/api/v1/journal?start_date=2024-01-12&end_date=2024-01-22"
        )
        data = response.json()
        assert data["total"] == 2  # Jan 15 and Jan 20

    async def test_filter_journal_entries_by_mood(self, client: AsyncClient):
        """Test filtering journal entries by mood."""
        moods = [("happy", 2), ("sad", 1), ("neutral", 1)]

        for mood, count in moods:
            for i in range(count):
                await client.post(
                    "/api/v1/journal",
                    json={
                        "title": f"{mood} entry {i}",
                        "content": "Content",
                        "entry_date": "2024-01-15",
                        "mood": mood,
                    },
                )

        # Filter by happy mood
        response = await client.get("/api/v1/journal?mood=happy")
        data = response.json()
        assert data["total"] == 2
        for item in data["items"]:
            assert item["mood"] == "happy"

    async def test_search_journal_entries(self, client: AsyncClient):
        """Test searching journal entries by content."""
        entries = [
            {"title": "Work Day", "content": "Finished the project at work"},
            {"title": "Exercise", "content": "Went to the gym"},
            {"title": "Work Meeting", "content": "Had important meetings"},
        ]

        for entry in entries:
            await client.post(
                "/api/v1/journal",
                json={**entry, "entry_date": "2024-01-15", "mood": "neutral"},
            )

        # Search for "work"
        response = await client.get("/api/v1/journal?search=work")
        data = response.json()
        assert data["total"] == 2  # "Work Day" and "Work Meeting"

    async def test_pagination(self, client: AsyncClient):
        """Test pagination of journal entries."""
        # Create 15 entries
        for i in range(15):
            await client.post(
                "/api/v1/journal",
                json={
                    "title": f"Entry {i + 1}",
                    "content": f"Content {i + 1}",
                    "entry_date": "2024-01-15",
                    "mood": "happy",
                },
            )

        # Get first page (limit 10)
        response = await client.get("/api/v1/journal?skip=0&limit=10")
        data = response.json()
        assert data["total"] == 15
        assert len(data["items"]) == 10

        # Get second page
        response = await client.get("/api/v1/journal?skip=10&limit=10")
        data = response.json()
        assert data["total"] == 15
        assert len(data["items"]) == 5


@pytest.mark.asyncio
class TestJournalUpdate:
    """Tests for updating journal entries."""

    async def test_update_journal_title(self, client: AsyncClient):
        """Test updating journal entry title."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Original Title",
                "content": "Content",
                "entry_date": "2024-01-15",
                "mood": "happy",
            },
        )
        entry_id = create_response.json()["id"]

        # Update title
        response = await client.patch(
            f"/api/v1/journal/{entry_id}", json={"title": "Updated Title"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated Title"
        assert data["content"] == "Content"  # unchanged

    async def test_update_journal_content(self, client: AsyncClient):
        """Test updating journal entry content."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Title",
                "content": "Original content",
                "entry_date": "2024-01-15",
                "mood": "happy",
            },
        )
        entry_id = create_response.json()["id"]

        # Update content
        response = await client.patch(
            f"/api/v1/journal/{entry_id}",
            json={"content": "Updated content with more details"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content"] == "Updated content with more details"

    async def test_update_journal_mood(self, client: AsyncClient):
        """Test updating journal entry mood."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Title",
                "content": "Content",
                "entry_date": "2024-01-15",
                "mood": "happy",
            },
        )
        entry_id = create_response.json()["id"]

        # Update mood
        response = await client.patch(
            f"/api/v1/journal/{entry_id}", json={"mood": "sad"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["mood"] == "sad"

    async def test_update_journal_tags(self, client: AsyncClient):
        """Test updating journal entry tags."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Title",
                "content": "Content",
                "entry_date": "2024-01-15",
                "mood": "happy",
                "tags": "work,project",
            },
        )
        entry_id = create_response.json()["id"]

        # Update tags
        response = await client.patch(
            f"/api/v1/journal/{entry_id}", json={"tags": "work,completed,success"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["tags"] == "work,completed,success"

    async def test_update_multiple_fields(self, client: AsyncClient):
        """Test updating multiple fields at once."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "Original",
                "content": "Original content",
                "entry_date": "2024-01-15",
                "mood": "happy",
            },
        )
        entry_id = create_response.json()["id"]

        # Update multiple fields
        response = await client.patch(
            f"/api/v1/journal/{entry_id}",
            json={
                "title": "Updated",
                "content": "Updated content",
                "mood": "excited",
                "tags": "new,tags",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated"
        assert data["content"] == "Updated content"
        assert data["mood"] == "excited"
        assert data["tags"] == "new,tags"

    async def test_update_nonexistent_journal_entry(self, client: AsyncClient):
        """Test updating nonexistent journal entry returns 404."""
        response = await client.patch("/api/v1/journal/9999", json={"title": "Test"})
        assert response.status_code == 404


@pytest.mark.asyncio
class TestJournalDelete:
    """Tests for deleting journal entries."""

    async def test_delete_journal_entry(self, client: AsyncClient):
        """Test deleting a journal entry."""
        # Create entry
        create_response = await client.post(
            "/api/v1/journal",
            json={
                "title": "To be deleted",
                "content": "This will be deleted",
                "entry_date": "2024-01-15",
                "mood": "neutral",
            },
        )
        entry_id = create_response.json()["id"]

        # Delete entry
        response = await client.delete(f"/api/v1/journal/{entry_id}")
        assert response.status_code == 204

        # Verify it's deleted
        get_response = await client.get(f"/api/v1/journal/{entry_id}")
        assert get_response.status_code == 404

    async def test_delete_nonexistent_journal_entry(self, client: AsyncClient):
        """Test deleting nonexistent journal entry returns 404."""
        response = await client.delete("/api/v1/journal/9999")
        assert response.status_code == 404
