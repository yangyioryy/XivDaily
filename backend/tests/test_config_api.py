from fastapi.testclient import TestClient

from app.api.config import get_config_service
from app.core.config import Settings
from app.main import app
from app.services.config_service import ConfigService


def build_service(tmp_path) -> ConfigService:
    settings = Settings()
    settings.database_url = f"sqlite:///{tmp_path / 'xivdaily.db'}"
    settings.llm_api_key = None
    settings.zotero_api_key = None
    return ConfigService(settings=settings)


def test_config_save_and_read_masks_sensitive_fields(tmp_path) -> None:
    service = build_service(tmp_path)
    app.dependency_overrides[get_config_service] = lambda: service
    client = TestClient(app)

    zotero_response = client.put(
        "/config/zotero",
        json={
            "user_id": "12345678",
            "library_type": "user",
            "api_key": "zotero-secret-key",
            "target_collection_name": "Daily Papers",
        },
    )
    llm_response = client.put(
        "/config/llm",
        json={
            "base_url": "https://llm.example.test/v1/",
            "api_key": "llm-secret-key",
            "model": "gpt-test",
        },
    )
    read_response = client.get("/config/integrations")

    app.dependency_overrides.clear()
    assert zotero_response.status_code == 200
    assert llm_response.status_code == 200
    assert read_response.status_code == 200
    body = read_response.json()
    assert body["zotero"]["user_id"] == "12345678"
    assert body["zotero"]["api_key"] == {"configured": True, "masked": "***-key"}
    assert body["zotero"]["target_collection_name"] == "Daily Papers"
    assert body["llm"]["base_url"] == "https://llm.example.test/v1"
    assert body["llm"]["api_key"] == {"configured": True, "masked": "***-key"}
    assert "secret" not in read_response.text


def test_config_test_reports_missing_fields(tmp_path) -> None:
    service = build_service(tmp_path)
    app.dependency_overrides[get_config_service] = lambda: service
    client = TestClient(app)

    zotero_response = client.post("/config/zotero/test")
    llm_response = client.post("/config/llm/test")

    app.dependency_overrides.clear()
    assert zotero_response.json()["ok"] is False
    assert zotero_response.json()["status"] == "not_configured"
    assert llm_response.json()["ok"] is False
    assert llm_response.json()["status"] == "not_configured"
