"""
Tests for Category CRUD operations.
"""

# [review:need-review] PHASE-01/31-web-quickfixes-md-fab-checklist
# summary: + tests for 422 on checklist mode without a boolean field (create & patch)

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud import category as category_crud
from app.models import Category


@pytest.mark.asyncio
class TestCategoryCreate:
    """Tests for creating categories."""

    async def test_create_category_without_fields(self, client: AsyncClient):
        """Test creating a category without fields."""
        response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Sleep",
                "description": "Track sleep quality",
                "color": "#3B82F6",
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Sleep"
        assert data["description"] == "Track sleep quality"
        assert data["color"] == "#3B82F6"
        assert data["is_active"] is True
        assert "id" in data
        assert "created_at" in data

    async def test_create_category_with_fields(self, client: AsyncClient):
        """Test creating a category with fields."""
        response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Sleep",
                "description": "Track sleep quality",
                "color": "#3B82F6",
                "fields": [
                    {
                        "name": "Duration (hours)",
                        "field_type": "number",
                        "is_required": True,
                        "order": 1,
                    },
                    {
                        "name": "Quality",
                        "field_type": "select",
                        "options": "poor,average,excellent",
                        "is_required": False,
                        "order": 2,
                    },
                ],
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Sleep"
        assert len(data["fields"]) == 2
        assert data["fields"][0]["name"] == "Duration (hours)"
        assert data["fields"][0]["field_type"] == "number"
        assert data["fields"][1]["name"] == "Quality"
        assert data["fields"][1]["field_type"] == "select"
        assert data["fields"][1]["options"] == "poor,average,excellent"

    async def test_create_category_defaults_display_mode_and_group(
        self, client: AsyncClient
    ):
        """Category created without new fields gets display_mode=form, group=None."""
        response = await client.post("/api/v1/categories", json={"name": "Sleep"})
        assert response.status_code == 201
        data = response.json()
        assert data["display_mode"] == "form"
        assert data["group"] is None

    async def test_create_category_with_display_mode_and_group(
        self, client: AsyncClient
    ):
        """Category can be created with checklist mode and a group."""
        response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Vitamins",
                "display_mode": "checklist",
                "group": "Health",
                "fields": [{"name": "Taken", "field_type": "boolean"}],
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["display_mode"] == "checklist"
        assert data["group"] == "Health"

    async def test_create_category_invalid_display_mode(self, client: AsyncClient):
        """Garbage display_mode is rejected with 422."""
        response = await client.post(
            "/api/v1/categories",
            json={"name": "Vitamins", "display_mode": "carousel"},
        )
        assert response.status_code == 422

    async def test_create_category_duplicate_name(self, client: AsyncClient):
        """Test creating a category with duplicate name fails."""
        # Create first category
        await client.post(
            "/api/v1/categories", json={"name": "Sleep", "description": "Track sleep"}
        )

        # Try to create duplicate
        response = await client.post(
            "/api/v1/categories",
            json={"name": "Sleep", "description": "Another sleep tracker"},
        )
        assert response.status_code == 400
        assert "already exists" in response.json()["detail"]


@pytest.mark.asyncio
class TestCategoryRead:
    """Tests for reading categories."""

    async def test_get_all_categories(self, client: AsyncClient):
        """Test getting all categories."""
        # Create test categories
        await client.post(
            "/api/v1/categories", json={"name": "Sleep", "description": "Track sleep"}
        )
        await client.post(
            "/api/v1/categories",
            json={"name": "Exercise", "description": "Track exercise"},
        )

        response = await client.get("/api/v1/categories")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        # Check that both categories are present (order may vary)
        names = [cat["name"] for cat in data]
        assert "Sleep" in names
        assert "Exercise" in names

    async def test_get_category_by_id(self, client: AsyncClient):
        """Test getting a specific category by ID."""
        # Create category
        create_response = await client.post(
            "/api/v1/categories", json={"name": "Sleep", "description": "Track sleep"}
        )
        category_id = create_response.json()["id"]

        # Get category
        response = await client.get(f"/api/v1/categories/{category_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == category_id
        assert data["name"] == "Sleep"

    async def test_get_nonexistent_category(self, client: AsyncClient):
        """Test getting a nonexistent category returns 404."""
        response = await client.get("/api/v1/categories/9999")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]

    async def test_get_active_categories_only(self, client: AsyncClient):
        """Test filtering active categories."""
        # Create active and inactive categories
        await client.post(
            "/api/v1/categories", json={"name": "Active", "is_active": True}
        )
        create_response = await client.post(
            "/api/v1/categories", json={"name": "Inactive", "is_active": True}
        )
        inactive_id = create_response.json()["id"]

        # Deactivate one
        await client.patch(
            f"/api/v1/categories/{inactive_id}", json={"is_active": False}
        )

        # Get active only
        response = await client.get("/api/v1/categories?active_only=true")
        data = response.json()
        assert len(data) == 1
        assert data[0]["name"] == "Active"


@pytest.mark.asyncio
class TestCategoryUpdate:
    """Tests for updating categories."""

    async def test_update_category_name(self, client: AsyncClient):
        """Test updating category name."""
        # Create category
        create_response = await client.post(
            "/api/v1/categories", json={"name": "Sleep", "description": "Track sleep"}
        )
        category_id = create_response.json()["id"]

        # Update category
        response = await client.patch(
            f"/api/v1/categories/{category_id}", json={"name": "Sleep Quality"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Sleep Quality"
        assert data["description"] == "Track sleep"  # unchanged

    async def test_update_category_description_and_color(self, client: AsyncClient):
        """Test updating multiple fields."""
        # Create category
        create_response = await client.post(
            "/api/v1/categories",
            json={"name": "Sleep", "description": "Track sleep", "color": "#000000"},
        )
        category_id = create_response.json()["id"]

        # Update
        response = await client.patch(
            f"/api/v1/categories/{category_id}",
            json={"description": "Monitor sleep patterns", "color": "#FF0000"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["description"] == "Monitor sleep patterns"
        assert data["color"] == "#FF0000"
        assert data["name"] == "Sleep"  # unchanged

    async def test_update_category_display_mode_and_group(self, client: AsyncClient):
        """Existing category with a boolean field can be switched to checklist mode."""
        create_response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Vitamins",
                "fields": [{"name": "Taken", "field_type": "boolean"}],
            },
        )
        category_id = create_response.json()["id"]

        response = await client.patch(
            f"/api/v1/categories/{category_id}",
            json={"display_mode": "checklist", "group": "Health"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["display_mode"] == "checklist"
        assert data["group"] == "Health"
        assert data["name"] == "Vitamins"  # unchanged

    async def test_update_category_invalid_display_mode(self, client: AsyncClient):
        """Garbage display_mode in PATCH is rejected with 422."""
        create_response = await client.post(
            "/api/v1/categories", json={"name": "Vitamins"}
        )
        category_id = create_response.json()["id"]

        response = await client.patch(
            f"/api/v1/categories/{category_id}", json={"display_mode": "grid"}
        )
        assert response.status_code == 422

    async def test_create_checklist_without_boolean_field_rejected(
        self, client: AsyncClient
    ):
        """POST with display_mode=checklist and no boolean field returns 422."""
        response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Coffee",
                "display_mode": "checklist",
                "fields": [{"name": "Cups", "field_type": "number"}],
            },
        )
        assert response.status_code == 422
        assert "boolean" in response.json()["detail"].lower()

    async def test_create_checklist_without_any_fields_rejected(
        self, client: AsyncClient
    ):
        """POST with display_mode=checklist and empty fields returns 422."""
        response = await client.post(
            "/api/v1/categories",
            json={"name": "Coffee", "display_mode": "checklist"},
        )
        assert response.status_code == 422
        assert "boolean" in response.json()["detail"].lower()

    async def test_patch_to_checklist_without_boolean_field_rejected(
        self, client: AsyncClient
    ):
        """PATCH switching to checklist fails with 422 when no boolean field exists."""
        create_response = await client.post(
            "/api/v1/categories",
            json={
                "name": "Coffee",
                "fields": [{"name": "Cups", "field_type": "number"}],
            },
        )
        category_id = create_response.json()["id"]

        response = await client.patch(
            f"/api/v1/categories/{category_id}", json={"display_mode": "checklist"}
        )
        assert response.status_code == 422
        assert "boolean" in response.json()["detail"].lower()

        # Category is untouched by the rejected patch
        get_response = await client.get(f"/api/v1/categories/{category_id}")
        assert get_response.json()["display_mode"] == "form"

    async def test_update_nonexistent_category(self, client: AsyncClient):
        """Test updating nonexistent category returns 404."""
        response = await client.patch(
            "/api/v1/categories/9999", json={"name": "New Name"}
        )
        assert response.status_code == 404


@pytest.mark.asyncio
class TestCategoryDelete:
    """Tests for deleting categories."""

    async def test_delete_category(self, client: AsyncClient):
        """Test deleting a category."""
        # Create category
        create_response = await client.post(
            "/api/v1/categories", json={"name": "Sleep", "description": "Track sleep"}
        )
        category_id = create_response.json()["id"]

        # Delete category
        response = await client.delete(f"/api/v1/categories/{category_id}")
        assert response.status_code == 204

        # Verify it's deleted
        get_response = await client.get(f"/api/v1/categories/{category_id}")
        assert get_response.status_code == 404

    async def test_delete_nonexistent_category(self, client: AsyncClient):
        """Test deleting nonexistent category returns 404."""
        response = await client.delete("/api/v1/categories/9999")
        assert response.status_code == 404


@pytest.mark.asyncio
class TestCategoryFields:
    """Tests for category field operations."""

    async def test_add_field_to_category(self, client: AsyncClient):
        """Test adding a field to existing category."""
        # Create category
        create_response = await client.post(
            "/api/v1/categories", json={"name": "Sleep", "description": "Track sleep"}
        )
        category_id = create_response.json()["id"]

        # Add field
        response = await client.post(
            f"/api/v1/categories/{category_id}/fields",
            json={"name": "Duration", "field_type": "number", "is_required": True},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Duration"
        assert data["field_type"] == "number"
        assert data["is_required"] is True
        assert data["category_id"] == category_id

    async def test_add_field_to_nonexistent_category(self, client: AsyncClient):
        """Test adding field to nonexistent category fails."""
        response = await client.post(
            "/api/v1/categories/9999/fields",
            json={"name": "Test", "field_type": "text"},
        )
        assert response.status_code == 404


@pytest.mark.asyncio
class TestGetCategoriesLimit:
    """Tests for the limit parameter of crud.category.get_categories."""

    async def test_limit_none_returns_all(self, db_session: AsyncSession) -> None:
        """limit=None disables pagination and returns every active category."""
        for i in range(3):
            db_session.add(Category(name=f"Cat {i}"))
        await db_session.commit()

        limited = await category_crud.get_categories(db_session, limit=2)
        assert len(limited) == 2

        unlimited = await category_crud.get_categories(db_session, limit=None)
        assert len(unlimited) == 3
