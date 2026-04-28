from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.models.sync_record import SyncRecordModel
from app.schemas.paper import Paper, PaperListResponse, PaperQuery
from app.schemas.zotero import BibtexExportRequest
from app.services.zotero_service import ZoteroService


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
        return PaperListResponse(query=query, items=[paper], page=1, page_size=10, total=1, has_more=False)


class FakeZoteroClient:
    def __init__(self, configured: bool = True) -> None:
        self._configured = configured
        self.calls = 0
        self.settings = type("Settings", (), {"zotero_user_id": "12345", "zotero_library_type": "user"})()

    def is_configured(self) -> bool:
        return self._configured

    async def create_item(self, item_payload: dict[str, object]) -> dict[str, object]:
        self.calls += 1
        return {"successful": {"0": {"key": "ABCD1234"}}}


def build_session() -> Session:
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine, class_=Session, autoflush=False, autocommit=False)()


def test_config_status_reports_missing_credentials() -> None:
    service = ZoteroService(zotero_client=FakeZoteroClient(configured=False), paper_service=FakePaperService())

    result = service.get_config_status()

    assert result.configured is False
    assert "未完成" in result.warning


@pytest.mark.anyio("asyncio")
async def test_sync_paper_is_idempotent_after_success() -> None:
    db = build_session()
    client = FakeZoteroClient(configured=True)
    service = ZoteroService(zotero_client=client, paper_service=FakePaperService())

    first = await service.sync_paper(db, "2401.00001")
    second = await service.sync_paper(db, "2401.00001")

    assert first.status == "synced"
    assert second.status == "synced"
    assert client.calls == 1


@pytest.mark.anyio("asyncio")
async def test_export_bibtex_returns_entries() -> None:
    service = ZoteroService(zotero_client=FakeZoteroClient(configured=True), paper_service=FakePaperService())

    result = await service.export_bibtex(BibtexExportRequest(paper_ids=["2401.00001"]))

    assert result.exported_count == 1
    assert "@misc{" in result.content
    assert "arXiv:2401.00001" in result.content

