from datetime import UTC, datetime, timedelta
import json

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.models.paper_record import PaperRecordModel
from app.schemas.paper import PaperQuery
from app.clients.arxiv_client import ArxivSearchResult
from app.services.paper_service import PaperService


class FakeArxivClient:
    def __init__(self, items: list[dict[str, object]]) -> None:
        self.items = items
        self.requests: list[tuple[str | None, str | None, int]] = []

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        self.requests.append((category, keyword, max_results))
        return self.items


class StatusFakeArxivClient:
    def __init__(self, result: ArxivSearchResult) -> None:
        self.result = result
        self.requests: list[tuple[str | None, str | None, int]] = []

    async def search_with_status(
        self,
        category: str | None,
        keyword: str | None,
        max_results: int,
    ) -> ArxivSearchResult:
        self.requests.append((category, keyword, max_results))
        return self.result


class SequencedStatusFakeArxivClient:
    def __init__(self, results: list[ArxivSearchResult]) -> None:
        self.results = results
        self.requests: list[tuple[str | None, str | None, int]] = []

    async def search_with_status(
        self,
        category: str | None,
        keyword: str | None,
        max_results: int,
    ) -> ArxivSearchResult:
        self.requests.append((category, keyword, max_results))
        return self.results.pop(0)


@pytest.fixture(autouse=True)
def clear_remote_search_cache() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()


def build_session() -> Session:
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine, class_=Session, autoflush=False, autocommit=False)()


def add_paper_record(
    db: Session,
    *,
    paper_id: str,
    title: str,
    categories: list[str],
    published_at: datetime,
    synced_at: datetime,
    summary: str = "Summary",
    primary_category: str | None = None,
) -> None:
    db.add(
        PaperRecordModel(
            paper_id=paper_id,
            title=title,
            authors_json=json.dumps(["A. Author"], ensure_ascii=False),
            summary=summary,
            published_at=published_at,
            updated_at=published_at,
            categories_json=json.dumps(categories, ensure_ascii=False),
            primary_category=primary_category or categories[0],
            source_url=f"https://arxiv.org/abs/{paper_id}",
            pdf_url=f"https://arxiv.org/pdf/{paper_id}",
            synced_at=synced_at,
        )
    )
    db.commit()


def build_arxiv_item(
    *,
    paper_id: str,
    title: str,
    categories: list[str],
    published_at: datetime,
    summary: str = "Summary",
    primary_category: str | None = None,
) -> dict[str, object]:
    return {
        "id": paper_id,
        "title": title,
        "authors": ["A. Author"],
        "summary": summary,
        "published_at": published_at.isoformat(),
        "updated_at": published_at.isoformat(),
        "categories": categories,
        "primary_category": primary_category or categories[0],
        "source_url": f"https://arxiv.org/abs/{paper_id}",
        "pdf_url": f"https://arxiv.org/pdf/{paper_id}",
    }


@pytest.mark.anyio("asyncio")
async def test_list_papers_returns_unavailable_when_local_library_is_empty() -> None:
    db = build_session()
    service = PaperService(db=db)

    result = await service.list_papers(PaperQuery(category="cs.CV", keyword=None, days=3, page=1, page_size=10))

    assert result.total == 0
    assert result.items == []
    assert result.status == "unavailable"
    assert result.warning == "本地论文库尚未同步完成，请稍后重试。"
    assert result.empty_reason is None


@pytest.mark.anyio("asyncio")
async def test_list_papers_filters_local_records_by_category_and_days() -> None:
    db = build_session()
    now = datetime.now(UTC)
    add_paper_record(
        db,
        paper_id="2401.00001",
        title="Vision Paper",
        categories=["cs.CV"],
        published_at=now - timedelta(days=1),
        synced_at=now,
    )
    add_paper_record(
        db,
        paper_id="2401.00002",
        title="Old Vision Paper",
        categories=["cs.CV"],
        published_at=now - timedelta(days=10),
        synced_at=now,
    )
    service = PaperService(db=db)

    result = await service.list_papers(PaperQuery(category="cs.CV", keyword=None, days=3, page=1, page_size=10))

    assert result.total == 1
    assert result.items[0].id == "2401.00001"
    assert result.status == "ok"
    assert result.warning is None
    assert result.empty_reason is None


@pytest.mark.anyio("asyncio")
async def test_list_papers_marks_time_window_filtered_empty_state_for_local_library() -> None:
    db = build_session()
    now = datetime.now(UTC)
    add_paper_record(
        db,
        paper_id="2604.20806v1",
        title="OMIBench",
        categories=["cs.CV", "cs.AI", "cs.CL"],
        primary_category="cs.CV",
        published_at=now - timedelta(days=7),
        synced_at=now,
    )
    service = PaperService(db=db)

    result = await service.list_papers(PaperQuery(category="cs.AI", keyword="omibench", days=3, page=1, page_size=10))

    assert result.total == 0
    assert result.items == []
    assert result.status == "empty"
    assert result.empty_reason == "time_window_filtered"
    assert result.warning == "当前 3 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。"


@pytest.mark.anyio("asyncio")
async def test_keyword_search_queries_arxiv_without_time_window() -> None:
    db = build_session()
    now = datetime.now(UTC)
    arxiv_client = FakeArxivClient(
        [
            build_arxiv_item(
                paper_id="2604.20806v1",
                title="OMIBench",
                categories=["cs.CV", "cs.AI", "cs.CL"],
                primary_category="cs.CV",
                published_at=now - timedelta(days=300),
                summary="A benchmark for embodied AI",
            )
        ]
    )
    service = PaperService(db=db, arxiv_client=arxiv_client)

    result = await service.list_papers(PaperQuery(category="cs.AI", keyword="omibench", days=None, page=1, page_size=10))

    assert arxiv_client.requests == [("cs.AI", "omibench", 50)]
    assert result.total == 1
    assert result.items[0].id == "2604.20806v1"
    assert result.items[0].primary_category == "cs.CV"
    assert result.items[0].categories == ["cs.CV", "cs.AI", "cs.CL"]
    assert result.status == "ok"
    assert result.warning is None
    assert result.empty_reason is None


@pytest.mark.anyio("asyncio")
async def test_keyword_search_with_days_uses_local_library_time_window() -> None:
    db = build_session()
    now = datetime.now(UTC)
    add_paper_record(
        db,
        paper_id="2604.20806v1",
        title="OMIBench",
        categories=["cs.CV", "cs.AI", "cs.CL"],
        primary_category="cs.CV",
        published_at=now - timedelta(days=2),
        synced_at=now,
        summary="A benchmark for embodied AI",
    )
    arxiv_client = FakeArxivClient(
        [
            build_arxiv_item(
                paper_id="9999.99999",
                title="Remote OMIBench",
                categories=["cs.AI"],
                published_at=now,
            )
        ]
    )
    service = PaperService(db=db, arxiv_client=arxiv_client)

    result = await service.list_papers(PaperQuery(category=None, keyword="omibench", days=3, page=1, page_size=10))

    assert arxiv_client.requests == []
    assert result.total == 1
    assert result.items[0].id == "2604.20806v1"
    assert result.status == "ok"
    assert result.warning is None


@pytest.mark.anyio("asyncio")
async def test_list_papers_marks_stale_when_latest_sync_is_too_old() -> None:
    db = build_session()
    now = datetime.now(UTC)
    add_paper_record(
        db,
        paper_id="2401.00001",
        title="Vision Paper",
        categories=["cs.CV"],
        published_at=now - timedelta(days=1),
        synced_at=now - timedelta(hours=2),
    )
    service = PaperService(db=db)
    service.settings.paper_library_stale_after_seconds = 60

    result = await service.list_papers(PaperQuery(category="cs.CV", keyword=None, days=3, page=1, page_size=10))

    assert result.total == 1
    assert result.status == "stale"
    assert result.warning == "本地论文库数据已过期，当前展示的是最近一次同步结果。"
    assert result.items[0].id == "2401.00001"


@pytest.mark.anyio("asyncio")
async def test_list_papers_marks_no_results_after_keyword_filtering() -> None:
    db = build_session()
    now = datetime.now(UTC)
    add_paper_record(
        db,
        paper_id="2401.00001",
        title="Vision Paper",
        categories=["cs.CV"],
        published_at=now - timedelta(days=1),
        synced_at=now,
    )
    service = PaperService(db=db)

    result = await service.list_papers(PaperQuery(category="cs.CV", keyword="diffusion", days=30, page=1, page_size=10))

    assert result.total == 0
    assert result.status == "empty"
    assert result.empty_reason == "no_results"
    assert result.warning is None


@pytest.mark.anyio("asyncio")
async def test_remote_keyword_search_exposes_rate_limit_warning() -> None:
    db = build_session()
    arxiv_client = StatusFakeArxivClient(
        ArxivSearchResult(
            items=[],
            status="rate_limited",
            warning="arXiv 当前限流，已重试但仍失败。可以稍后重试。",
        )
    )
    service = PaperService(db=db, arxiv_client=arxiv_client)

    result = await service.list_papers(PaperQuery(category=None, keyword="omibench", days=None, page=1, page_size=10))

    assert arxiv_client.requests == [(None, "omibench", 50)]
    assert result.total == 0
    assert result.status == "unavailable"
    assert result.empty_reason == "rate_limited"
    assert result.warning == "arXiv 当前限流，已重试但仍失败。可以稍后重试。"


@pytest.mark.anyio("asyncio")
async def test_remote_keyword_search_keeps_plain_no_results_when_arxiv_is_empty() -> None:
    db = build_session()
    arxiv_client = StatusFakeArxivClient(ArxivSearchResult(items=[]))
    service = PaperService(db=db, arxiv_client=arxiv_client)

    result = await service.list_papers(PaperQuery(category=None, keyword="omibench", days=None, page=1, page_size=10))

    assert result.total == 0
    assert result.status == "empty"
    assert result.empty_reason == "no_results"
    assert result.warning is None


@pytest.mark.anyio("asyncio")
async def test_remote_keyword_search_explains_category_filtered_results() -> None:
    db = build_session()
    now = datetime.now(UTC)
    arxiv_client = StatusFakeArxivClient(
        ArxivSearchResult(
            items=[
                build_arxiv_item(
                    paper_id="2604.20806v1",
                    title="OMIBench",
                    categories=["cs.AI"],
                    published_at=now,
                    summary="A benchmark for embodied AI",
                )
            ]
        )
    )
    service = PaperService(db=db, arxiv_client=arxiv_client)

    result = await service.list_papers(PaperQuery(category="cs.CV", keyword="omibench", days=None, page=1, page_size=10))

    assert result.total == 0
    assert result.status == "empty"
    assert result.empty_reason == "category_filtered"
    assert result.warning == "arXiv 找到了相关论文，但当前分类没有命中。可以切换分类或清空分类后再搜索。"


@pytest.mark.anyio("asyncio")
async def test_remote_keyword_search_does_not_cache_rate_limited_result() -> None:
    db = build_session()
    now = datetime.now(UTC)
    arxiv_client = SequencedStatusFakeArxivClient(
        [
            ArxivSearchResult(items=[], status="rate_limited", warning="arXiv 当前限流。"),
            ArxivSearchResult(
                items=[
                    build_arxiv_item(
                        paper_id="2604.20806v1",
                        title="OMIBench",
                        categories=["cs.CV"],
                        published_at=now,
                    )
                ]
            ),
        ]
    )
    service = PaperService(db=db, arxiv_client=arxiv_client)
    query = PaperQuery(category="cs.CV", keyword="omibench", days=None, page=1, page_size=10)

    first = await service.list_papers(query)
    second = await service.list_papers(query)

    assert first.status == "unavailable"
    assert first.empty_reason == "rate_limited"
    assert second.status == "ok"
    assert second.items[0].id == "2604.20806v1"
    assert arxiv_client.requests == [("cs.CV", "omibench", 50), ("cs.CV", "omibench", 50)]
