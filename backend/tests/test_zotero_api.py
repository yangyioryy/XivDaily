from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.api.zotero import get_zotero_service
from app.main import app
from app.schemas.zotero import BibtexExportResponse, ZoteroConfigStatus


class FakeZoteroService:
    def get_config_status(self) -> ZoteroConfigStatus:
        return ZoteroConfigStatus(configured=True, user_id="12345", library_type="user")

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

    response = client.get("/zotero/config/status")

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["configured"] is True


def test_zotero_export_api_returns_bibtex() -> None:
    app.dependency_overrides[get_zotero_service] = lambda: FakeZoteroService()
    client = TestClient(app)

    response = client.post("/zotero/exports/bibtex", json={"paper_ids": ["2401.00001"]})

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["exported_count"] == 1


def test_zotero_sync_api_returns_sync_payload() -> None:
    app.dependency_overrides[get_zotero_service] = lambda: FakeZoteroService()
    client = TestClient(app)

    response = client.post("/zotero/sync/2401.00001")

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["paper_id"] == "2401.00001"
    assert response.json()["status"] == "synced"
