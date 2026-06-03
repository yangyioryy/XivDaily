from datetime import UTC, datetime, timedelta
import json

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.models.paper_record import PaperRecordModel
from app.services.paper_sync_service import PaperSyncService


class FakeArxivClient:
    def __init__(self) -> None:
        self.requests: list[tuple[str | None, str | None, int]] = []

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        self.requests.append((category, keyword, max_results))
        now = datetime.now(UTC)
        if category == "cs.CV":
            return [
                {
                    "id": "2401.00001",
                    "title": "Vision Paper",
                    "authors": ["A. Author"],
                    "summary": "Summary",
                    "published_at": now.isoformat(),
                    "updated_at": now.isoformat(),
                    "categories": ["cs.CV"],
                    "primary_category": "cs.CV",
                    "source_url": "https://arxiv.org/abs/2401.00001",
                    "pdf_url": "https://arxiv.org/pdf/2401.00001",
                }
            ]
        return [
            {
                "id": "2401.00002",
                "title": "AI Paper",
                "authors": ["B. Author"],
                "summary": "Summary",
                "published_at": now.isoformat(),
                "updated_at": now.isoformat(),
                "categories": ["cs.AI"],
                "primary_category": "cs.AI",
                "source_url": "https://arxiv.org/abs/2401.00002",
                "pdf_url": "https://arxiv.org/pdf/2401.00002",
            }
        ]


class PartiallyFailingArxivClient:
    def __init__(self) -> None:
        self.requests: list[tuple[str | None, str | None, int]] = []

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        self.requests.append((category, keyword, max_results))
        if category == "cs.CV":
            raise RuntimeError("temporary arxiv failure")

        now = datetime.now(UTC)
        return [
            {
                "id": "2401.00003",
                "title": "Recovered AI Paper",
                "authors": ["C. Author"],
                "summary": "Summary",
                "published_at": now.isoformat(),
                "updated_at": now.isoformat(),
                "categories": ["cs.AI"],
                "primary_category": "cs.AI",
                "source_url": "https://arxiv.org/abs/2401.00003",
                "pdf_url": "https://arxiv.org/pdf/2401.00003",
            }
        ]


def build_session_factory() -> tuple[callable, Session]:
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(bind=engine)
    session_factory = sessionmaker(bind=engine, class_=Session, autoflush=False, autocommit=False)
    return session_factory, session_factory()


@pytest.mark.anyio("asyncio")
async def test_sync_once_upserts_records_for_each_category() -> None:
    session_factory, inspect_db = build_session_factory()
    client = FakeArxivClient()
    service = PaperSyncService(session_factory=session_factory, arxiv_client=client)
    service.settings.arxiv_sync_categories = '["cs.CV","cs.AI"]'
    service.settings.arxiv_sync_max_results = 50

    result = await service.sync_once()

    rows = inspect_db.scalars(select(PaperRecordModel).order_by(PaperRecordModel.paper_id)).all()
    assert result["upserted"] == 2
    assert result["deleted"] == 0
    assert [row.paper_id for row in rows] == ["2401.00001", "2401.00002"]
    assert json.loads(rows[0].authors_json) == ["A. Author"]
    assert client.requests == [("cs.CV", None, 50), ("cs.AI", None, 50)]


@pytest.mark.anyio("asyncio")
async def test_sync_once_cleans_up_expired_and_over_limit_records() -> None:
    session_factory, inspect_db = build_session_factory()
    old_time = datetime.now(UTC) - timedelta(days=30)
    inspect_db.add(
        PaperRecordModel(
            paper_id="old-paper",
            title="Old Paper",
            authors_json='["A. Author"]',
            summary="Summary",
            published_at=old_time,
            updated_at=old_time,
            categories_json='["cs.CV"]',
            primary_category="cs.CV",
            source_url="https://arxiv.org/abs/old-paper",
            pdf_url="https://arxiv.org/pdf/old-paper",
            synced_at=old_time,
        )
    )
    inspect_db.commit()

    client = FakeArxivClient()
    service = PaperSyncService(session_factory=session_factory, arxiv_client=client)
    service.settings.arxiv_sync_categories = '["cs.CV"]'
    service.settings.paper_library_retention_days = 14
    service.settings.paper_library_max_papers_per_category = 1

    result = await service.sync_once()

    rows = inspect_db.scalars(select(PaperRecordModel).order_by(PaperRecordModel.paper_id)).all()
    assert result["upserted"] == 1
    assert result["deleted"] == 1
    assert [row.paper_id for row in rows] == ["2401.00001"]


@pytest.mark.anyio("asyncio")
async def test_sync_once_continues_when_one_category_fails() -> None:
    session_factory, inspect_db = build_session_factory()
    client = PartiallyFailingArxivClient()
    service = PaperSyncService(session_factory=session_factory, arxiv_client=client)
    service.settings.arxiv_sync_categories = '["cs.CV","cs.AI"]'
    service.settings.arxiv_sync_max_results = 50

    result = await service.sync_once()

    rows = inspect_db.scalars(select(PaperRecordModel).order_by(PaperRecordModel.paper_id)).all()
    assert result["upserted"] == 1
    assert result["deleted"] == 0
    assert result["failed"] == 1
    assert [row.paper_id for row in rows] == ["2401.00003"]
    assert client.requests == [("cs.CV", None, 50), ("cs.AI", None, 50)]


@pytest.mark.anyio("asyncio")
async def test_sync_once_does_not_cleanup_failed_category_records() -> None:
    session_factory, inspect_db = build_session_factory()
    old_time = datetime.now(UTC) - timedelta(days=30)
    inspect_db.add(
        PaperRecordModel(
            paper_id="old-cv-paper",
            title="Old CV Paper",
            authors_json='["A. Author"]',
            summary="Summary",
            published_at=old_time,
            updated_at=old_time,
            categories_json='["cs.CV"]',
            primary_category="cs.CV",
            source_url="https://arxiv.org/abs/old-cv-paper",
            pdf_url="https://arxiv.org/pdf/old-cv-paper",
            synced_at=old_time,
        )
    )
    inspect_db.commit()

    client = PartiallyFailingArxivClient()
    service = PaperSyncService(session_factory=session_factory, arxiv_client=client)
    service.settings.arxiv_sync_categories = '["cs.CV","cs.AI"]'
    service.settings.paper_library_retention_days = 14

    result = await service.sync_once()

    rows = inspect_db.scalars(select(PaperRecordModel).order_by(PaperRecordModel.paper_id)).all()
    assert result["failed"] == 1
    assert [row.paper_id for row in rows] == ["2401.00003", "old-cv-paper"]
