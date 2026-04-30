import asyncio
from datetime import UTC, datetime, timedelta

import httpx
import pytest

from app.schemas.paper import PaperQuery
from app.services.paper_service import PaperService


class FakeArxivClient:
    def __init__(self) -> None:
        self.calls = 0

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        self.calls += 1
        now = datetime.now(UTC)
        old = now - timedelta(days=10)
        return [
            self._item("2401.00001", now.isoformat(), ["cs.CV"], "Vision Paper"),
            self._item("2401.00001", now.isoformat(), ["cs.CV"], "Vision Paper Duplicate"),
            self._item("2301.00001", old.isoformat(), ["cs.CV"], "Old Paper"),
        ]

    def _item(self, paper_id: str, published_at: str, categories: list[str], title: str) -> dict[str, object]:
        return {
            "id": paper_id,
            "title": title,
            "authors": ["A. Author"],
            "summary": "Summary",
            "published_at": published_at,
            "updated_at": published_at,
            "categories": categories,
            "primary_category": categories[0],
            "source_url": f"https://arxiv.org/abs/{paper_id}",
            "pdf_url": f"https://arxiv.org/pdf/{paper_id}",
        }


class TimeWindowArxivClient:
    def __init__(self) -> None:
        self.requests: list[tuple[str | None, str | None, int]] = []

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        self.requests.append((category, keyword, max_results))
        now = datetime.now(UTC)
        recent = now - timedelta(days=2)
        older = now - timedelta(days=7)
        items = [
            {
                "id": "2604.20806v1",
                "title": "OMIBench",
                "authors": ["A. Author"],
                "summary": "Summary",
                "published_at": older.isoformat(),
                "updated_at": older.isoformat(),
                "categories": ["cs.CV", "cs.AI", "cs.CL"],
                "primary_category": "cs.CV",
                "source_url": "https://arxiv.org/abs/2604.20806v1",
                "pdf_url": "https://arxiv.org/pdf/2604.20806v1",
            },
            {
                "id": "2604.25914v1",
                "title": "DV-World",
                "authors": ["B. Author"],
                "summary": "Summary",
                "published_at": recent.isoformat(),
                "updated_at": recent.isoformat(),
                "categories": ["cs.CL"],
                "primary_category": "cs.CL",
                "source_url": "https://arxiv.org/abs/2604.25914v1",
                "pdf_url": "https://arxiv.org/pdf/2604.25914v1",
            },
        ]
        normalized_keyword = (keyword or "").lower()
        matched: list[dict[str, object]] = []
        for item in items:
            categories = item["categories"]
            if category and category not in categories:
                continue
            if normalized_keyword:
                haystacks = [
                    str(item["id"]).lower(),
                    str(item["title"]).lower(),
                    str(item["summary"]).lower(),
                ]
                if not any(normalized_keyword in value for value in haystacks):
                    continue
            matched.append(item)
        return matched


class FailingArxivClient:
    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        request = httpx.Request("GET", "https://export.arxiv.org/api/query")
        response = httpx.Response(status_code=429, request=request)
        raise httpx.HTTPStatusError("rate limited", request=request, response=response)


class SlowArxivClient(FakeArxivClient):
    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        await asyncio.sleep(0.01)
        return await super().search(category, keyword, max_results)


@pytest.mark.anyio("asyncio")
async def test_list_papers_filters_dedupes_and_caches() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    fake_client = FakeArxivClient()
    service = PaperService(arxiv_client=fake_client)
    query = PaperQuery(category="cs.CV", keyword="vision", days=3, page=1, page_size=10)

    first = await service.list_papers(query)
    second = await service.list_papers(query)

    assert first.total == 1
    assert first.items[0].id == "2401.00001"
    assert first.has_more is False
    assert first.status == "ok"
    assert first.warning is None
    assert first.empty_reason is None
    assert second.total == 1
    assert fake_client.calls == 1


@pytest.mark.anyio("asyncio")
async def test_list_papers_reuses_shared_cache_across_service_instances() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    fake_client = FakeArxivClient()
    first_service = PaperService(arxiv_client=fake_client)
    second_service = PaperService(arxiv_client=fake_client)
    query = PaperQuery(category="cs.CV", keyword="shared-cache-case", days=3, page=1, page_size=10)

    first = await first_service.list_papers(query)
    second = await second_service.list_papers(query)

    assert first.total == 1
    assert second.total == 1
    assert fake_client.calls == 1


@pytest.mark.anyio("asyncio")
async def test_list_papers_returns_empty_result_when_arxiv_is_rate_limited_without_cache() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    service = PaperService(arxiv_client=FailingArxivClient())
    query = PaperQuery(category="cs.LG", keyword="rate-limit-case", days=3, page=1, page_size=10)

    result = await service.list_papers(query)

    assert result.total == 0
    assert result.items == []
    assert result.has_more is False
    assert result.status == "unavailable"
    assert result.warning == "arXiv 请求暂时不可用，请稍后重试。"
    assert result.empty_reason is None


@pytest.mark.anyio("asyncio")
async def test_list_papers_marks_time_window_filtered_empty_state() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    service = PaperService(arxiv_client=TimeWindowArxivClient())
    query = PaperQuery(category="cs.AI", keyword="omibench", days=3, page=1, page_size=10)

    result = await service.list_papers(query)

    assert result.total == 0
    assert result.items == []
    assert result.status == "empty"
    assert result.empty_reason == "time_window_filtered"
    assert result.warning == "当前 3 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。"


@pytest.mark.anyio("asyncio")
async def test_list_papers_keeps_cross_category_keyword_hit_when_time_window_is_wide_enough() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    service = PaperService(arxiv_client=TimeWindowArxivClient())
    query = PaperQuery(category="cs.AI", keyword="omibench", days=30, page=1, page_size=10)

    result = await service.list_papers(query)

    assert result.total == 1
    assert result.items[0].id == "2604.20806v1"
    assert result.items[0].primary_category == "cs.CV"
    assert result.items[0].categories == ["cs.CV", "cs.AI", "cs.CL"]
    assert result.status == "ok"
    assert result.warning is None
    assert result.empty_reason is None


@pytest.mark.anyio("asyncio")
async def test_list_papers_keeps_cross_category_hits_when_within_time_window() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    service = PaperService(arxiv_client=TimeWindowArxivClient())
    query = PaperQuery(category="cs.CL", keyword=None, days=3, page=1, page_size=10)

    result = await service.list_papers(query)

    assert result.total == 1
    assert result.items[0].id == "2604.25914v1"
    assert result.status == "ok"
    assert result.empty_reason is None


@pytest.mark.anyio("asyncio")
async def test_keyword_search_uses_full_arxiv_recall_and_skips_time_window_by_default() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    client = TimeWindowArxivClient()
    service = PaperService(arxiv_client=client)
    query = PaperQuery(category="cs.AI", keyword="omibench", days=None, page=1, page_size=10)

    result = await service.list_papers(query)

    assert result.total == 1
    assert result.items[0].id == "2604.20806v1"
    assert result.items[0].categories == ["cs.CV", "cs.AI", "cs.CL"]
    assert result.status == "ok"
    assert result.warning is None
    assert result.empty_reason is None
    assert client.requests[0][0] is None
    assert client.requests[0][1] == "omibench"


@pytest.mark.anyio("asyncio")
async def test_feed_cache_reuses_raw_items_when_only_days_changes() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    client = FakeArxivClient()
    service = PaperService(arxiv_client=client)

    first = await service.list_papers(PaperQuery(category="cs.CV", keyword=None, days=3, page=1, page_size=10))
    second = await service.list_papers(PaperQuery(category="cs.CV", keyword=None, days=30, page=1, page_size=10))

    assert first.total == 1
    assert second.total == 2
    assert client.calls == 1


@pytest.mark.anyio("asyncio")
async def test_same_cache_key_concurrent_requests_share_one_arxiv_call() -> None:
    PaperService._shared_cache.clear()
    PaperService._shared_inflight.clear()
    client = SlowArxivClient()
    first_service = PaperService(arxiv_client=client)
    second_service = PaperService(arxiv_client=client)
    query = PaperQuery(category="cs.CV", keyword=None, days=3, page=1, page_size=10)

    first, second = await asyncio.gather(
        first_service.list_papers(query),
        second_service.list_papers(query),
    )

    assert first.total == 1
    assert second.total == 1
    assert client.calls == 1
