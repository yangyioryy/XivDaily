from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.models.sync_record import SyncRecordModel
from app.schemas.paper import Paper, PaperListResponse, PaperQuery
from app.schemas.zotero import BibtexExportRequest
from app.services.zotero_service import ZoteroService


def config_status_to_dict(status: object) -> dict[str, object]:
    if isinstance(status, dict):
        return status
    if hasattr(status, "model_dump"):
        return status.model_dump()
    return {key: value for key, value in vars(status).items() if not key.startswith("_")}


def assert_collection_contract(payload: dict[str, object]) -> None:
    # 配置页最少要能拿到集合名和真实状态，否则前端无法展示统一归档集合信息。
    assert payload["target_collection_name"] == "XivDaily"
    assert payload["target_collection_status"] in {"not_configured", "ready", "created", "error"}
    collection_key = payload.get("target_collection_key")
    if payload["target_collection_status"] in {"ready", "created"}:
        assert isinstance(collection_key, str)
        assert collection_key.strip()


class FakePaperService:
    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        now = datetime.now(UTC)
        paper = Paper(
            id="2401.00001",
            title="Mock Vision Paper",
            authors=["Ada Lovelace"],
            summary="Summary",
            published_at=now,
            updated_at=now,
            categories=["cs.CV"],
            primary_category="cs.CV",
            source_url="https://arxiv.org/abs/2401.00001",
            pdf_url="https://arxiv.org/pdf/2401.00001",
        )
        return PaperListResponse(
            query=query,
            items=[paper],
            page=1,
            page_size=10,
            total=1,
            has_more=False,
            status="ok",
            warning=None,
            empty_reason=None,
        )


class FakeZoteroClient:
    def __init__(
        self,
        configured: bool = True,
        target_collection_name: str = "XivDaily",
        collection_created: bool = False,
        collection_key: str = "COLL1234",
    ) -> None:
        self._configured = configured
        self.calls = 0
        self._target_collection_name = target_collection_name
        self.collection_created = collection_created
        self.collection_key = collection_key
        self.last_item_payload: dict[str, object] | None = None
        self.item_visible = True
        self.repair_makes_item_visible = False
        self.collection_repairs: list[tuple[str, str]] = []
        self.settings = type("Settings", (), {"zotero_user_id": "12345", "zotero_library_type": "user"})()

    def is_configured(self) -> bool:
        return self._configured

    @property
    def target_collection_name(self) -> str:
        return self._target_collection_name

    async def get_or_create_collection(self, collection_name: str | None = None) -> dict[str, object]:
        return {
            "name": collection_name or self._target_collection_name,
            "key": self.collection_key,
            "created": self.collection_created,
        }

    async def create_item(self, item_payload: dict[str, object]) -> dict[str, object]:
        self.calls += 1
        self.last_item_payload = item_payload
        return {"successful": {"0": {"key": "ABCD1234"}}}

    async def is_item_in_collection(self, item_key: str, collection_key: str) -> bool:
        return self.item_visible

    async def add_item_to_collection(self, item_key: str, collection_key: str) -> None:
        self.collection_repairs.append((item_key, collection_key))
        if self.repair_makes_item_visible:
            self.item_visible = True


def build_session() -> Session:
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine, class_=Session, autoflush=False, autocommit=False)()


@pytest.mark.anyio("asyncio")
async def test_config_status_reports_missing_credentials() -> None:
    service = ZoteroService(zotero_client=FakeZoteroClient(configured=False), paper_service=FakePaperService())

    result = await service.get_config_status()

    assert result.configured is False
    assert result.warning is not None
    assert "未完成" in result.warning
    payload = config_status_to_dict(result)
    assert payload["target_collection_name"] == "XivDaily"
    assert payload["target_collection_status"] == "not_configured"


@pytest.mark.anyio("asyncio")
async def test_config_status_reports_collection_metadata_when_configured() -> None:
    service = ZoteroService(
        zotero_client=FakeZoteroClient(
            configured=True,
            target_collection_name="XivDaily",
            collection_created=False,
            collection_key="COLL1234",
        ),
        paper_service=FakePaperService(),
    )

    result = await service.get_config_status()
    payload = config_status_to_dict(result)

    assert payload["configured"] is True
    assert payload["user_id"] == "12345"
    assert payload["library_type"] == "user"
    assert payload["target_collection_status"] == "ready"
    assert_collection_contract(payload)


@pytest.mark.anyio("asyncio")
async def test_config_status_reports_created_collection_when_missing() -> None:
    service = ZoteroService(
        zotero_client=FakeZoteroClient(
            configured=True,
            target_collection_name="XivDaily",
            collection_created=True,
            collection_key="NEWCOLL1",
        ),
        paper_service=FakePaperService(),
    )

    result = await service.get_config_status()

    assert result.target_collection_status == "created"
    assert result.target_collection_key == "NEWCOLL1"


@pytest.mark.anyio("asyncio")
async def test_sync_paper_is_idempotent_after_success() -> None:
    db = build_session()
    client = FakeZoteroClient(configured=True)
    service = ZoteroService(zotero_client=client, paper_service=FakePaperService())

    first = await service.sync_paper(db, "2401.00001")
    second = await service.sync_paper(db, "2401.00001")

    assert first.status == "synced"
    assert second.status == "synced"
    assert first.visibility_status == "verified"
    assert first.target_collection_key == "COLL1234"
    assert client.calls == 1
    assert client.last_item_payload is not None
    assert client.last_item_payload["data"]["collections"] == ["COLL1234"]


@pytest.mark.anyio("asyncio")
async def test_sync_paper_repairs_collection_for_existing_synced_record() -> None:
    db = build_session()
    db.add(
        SyncRecordModel(
            paper_id="2401.00001",
            status="synced",
            zotero_item_key="ABCD1234",
            message="旧版本已同步，但未确认集合。",
            synced_at=datetime.now(UTC),
        )
    )
    db.commit()
    client = FakeZoteroClient(configured=True)
    client.item_visible = False
    client.repair_makes_item_visible = True
    service = ZoteroService(zotero_client=client, paper_service=FakePaperService())

    result = await service.sync_paper(db, "2401.00001")

    assert result.status == "synced"
    assert result.visibility_status == "verified"
    assert result.target_collection_key == "COLL1234"
    assert result.message == "已确认同步条目归档到目标集合。"
    assert client.calls == 0
    assert client.collection_repairs == [("ABCD1234", "COLL1234")]


@pytest.mark.anyio("asyncio")
async def test_sync_paper_repairs_collection_membership_when_visibility_is_missing() -> None:
    db = build_session()
    client = FakeZoteroClient(configured=True)
    client.item_visible = False
    client.repair_makes_item_visible = True
    service = ZoteroService(zotero_client=client, paper_service=FakePaperService())

    result = await service.sync_paper(db, "2401.00001")

    assert result.status == "synced"
    assert result.visibility_status == "verified"
    assert result.message == "同步成功，已归档到目标集合。"
    assert result.visibility_message == "已通过补偿归档确认条目出现在目标集合中。"
    assert client.collection_repairs == [("ABCD1234", "COLL1234")]


@pytest.mark.anyio("asyncio")
async def test_sync_paper_reports_missing_visibility_when_repair_still_fails() -> None:
    db = build_session()
    client = FakeZoteroClient(configured=True)
    client.item_visible = False
    service = ZoteroService(zotero_client=client, paper_service=FakePaperService())

    result = await service.sync_paper(db, "2401.00001")

    assert result.status == "synced"
    assert result.visibility_status == "missing_from_collection"
    assert "暂未在目标集合中确认可见" in (result.message or "")
    assert "已尝试补偿归档" in (result.visibility_message or "")


@pytest.mark.anyio("asyncio")
async def test_export_bibtex_returns_entries() -> None:
    service = ZoteroService(zotero_client=FakeZoteroClient(configured=True), paper_service=FakePaperService())

    result = await service.export_bibtex(BibtexExportRequest(paper_ids=["2401.00001"]))

    assert result.exported_count == 1
    assert "@misc{" in result.content
    assert "arXiv:2401.00001" in result.content
