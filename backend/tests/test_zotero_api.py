from datetime import UTC, datetime
from fastapi.testclient import TestClient

from app.api.zotero import get_zotero_service
from app.main import app
from app.schemas.zotero import BibtexExportResponse


def assert_collection_contract(payload: dict[str, object]) -> None:
    assert payload["target_collection_name"] == "XivDaily"
    assert payload["target_collection_status"] in {"ready", "created"}
    assert isinstance(payload["target_collection_key"], str)
    assert payload["target_collection_key"].strip()


class FakeZoteroService:
    async def get_config_status(self):
        return {
            "configured": True,
            "user_id": "12345",
            "library_type": "user",
            "target_collection_name": "XivDaily",
            "target_collection_status": "ready",
            "target_collection_key": "COLL1234",
            "warning": None,
        }

    async def sync_paper(self, db, paper_id: str):
        return type(
            "Record",
            (),
            {
                "paper_id": paper_id,
                "status": "synced",
                "zotero_item_key": "ABCD1234",
                "message": "同步成功。",
                "synced_at": datetime.now(UTC),
            },
        )()

    async def export_bibtex(self, request) -> BibtexExportResponse:
        return BibtexExportResponse(content="@misc{demo}", exported_count=1)


def test_zotero_config_api_returns_status() -> None:
    app.dependency_overrides[get_zotero_service] = lambda: FakeZoteroService()
    client = TestClient(app)

    try:
        response = client.get("/zotero/config/status")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["configured"] is True
    assert_collection_contract(payload)


def test_zotero_export_api_returns_bibtex() -> None:
    app.dependency_overrides[get_zotero_service] = lambda: FakeZoteroService()
    client = TestClient(app)

    try:
        response = client.post("/zotero/exports/bibtex", json={"paper_ids": ["2401.00001"]})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["exported_count"] == 1


def test_zotero_sync_api_returns_sync_payload() -> None:
    app.dependency_overrides[get_zotero_service] = lambda: FakeZoteroService()
    client = TestClient(app)

    try:
        response = client.post("/zotero/sync/2401.00001")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["paper_id"] == "2401.00001"
    assert response.json()["status"] == "synced"
