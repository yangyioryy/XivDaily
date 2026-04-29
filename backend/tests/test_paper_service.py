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


class FailingArxivClient:
    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        request = httpx.Request("GET", "https://export.arxiv.org/api/query")
        response = httpx.Response(status_code=429, request=request)
        raise httpx.HTTPStatusError("rate limited", request=request, response=response)


@pytest.mark.anyio("asyncio")
async def test_list_papers_filters_dedupes_and_caches() -> None:
    PaperService._shared_cache.clear()
    fake_client = FakeArxivClient()
    service = PaperService(arxiv_client=fake_client)
    query = PaperQuery(category="cs.CV", keyword="vision", days=3, page=1, page_size=10)

    first = await service.list_papers(query)
    second = await service.list_papers(query)

    assert first.total == 1
    assert first.items[0].id == "2401.00001"
    assert first.has_more is False
    assert second.total == 1
    assert fake_client.calls == 1


@pytest.mark.anyio("asyncio")
async def test_list_papers_reuses_shared_cache_across_service_instances() -> None:
    PaperService._shared_cache.clear()
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
    service = PaperService(arxiv_client=FailingArxivClient())
    query = PaperQuery(category="cs.LG", keyword="rate-limit-case", days=3, page=1, page_size=10)

    result = await service.list_papers(query)

    assert result.total == 0
    assert result.items == []
    assert result.has_more is False
