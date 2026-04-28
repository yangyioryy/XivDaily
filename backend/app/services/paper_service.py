from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from time import monotonic

from app.clients.arxiv_client import ArxivClient
from app.core.config import get_settings
from app.schemas.paper import Paper, PaperListResponse, PaperQuery


@dataclass
class CacheEntry:
    created_at: float
    items: list[dict[str, object]]


class PaperService:
    """论文查询服务，负责缓存、去重、日期过滤和分页。"""

    def __init__(self, arxiv_client: ArxivClient | None = None) -> None:
        self.settings = get_settings()
        self.arxiv_client = arxiv_client or ArxivClient()
        self._cache: dict[tuple[str | None, str | None], CacheEntry] = {}

    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        raw_items = await self._load_raw_items(query)
        normalized = [self._to_paper(item) for item in raw_items]
        filtered = self._filter_by_time_window(normalized, query.days)
        filtered = self._dedupe(filtered)
        start = (query.page - 1) * query.page_size
        end = start + query.page_size
        page_items = filtered[start:end]
        return PaperListResponse(
            query=query,
            items=page_items,
            page=query.page,
            page_size=query.page_size,
            total=len(filtered),
            has_more=end < len(filtered),
        )

    async def _load_raw_items(self, query: PaperQuery) -> list[dict[str, object]]:
        cache_key = (query.category, query.keyword)
        cached = self._cache.get(cache_key)
        if cached and monotonic() - cached.created_at < self.settings.arxiv_cache_ttl_seconds:
            return cached.items

        # arXiv API 不能可靠表达“最近 N 天”，先拉取较大窗口，再在本地按发布时间过滤。
        max_results = max(query.page * query.page_size * 3, 100)
        items = await self.arxiv_client.search(query.category, query.keyword, max_results)
        self._cache[cache_key] = CacheEntry(created_at=monotonic(), items=items)
        return items

    def _filter_by_time_window(self, papers: list[Paper], days: int) -> list[Paper]:
        cutoff = datetime.now(UTC) - timedelta(days=days)
        return [paper for paper in papers if paper.published_at >= cutoff]

    def _dedupe(self, papers: list[Paper]) -> list[Paper]:
        seen: set[str] = set()
        result: list[Paper] = []
        for paper in papers:
            if paper.id in seen:
                continue
            seen.add(paper.id)
            result.append(paper)
        return result

    def _to_paper(self, item: dict[str, object]) -> Paper:
        return Paper(
            id=str(item["id"]),
            title=str(item["title"]),
            authors=list(item["authors"]),
            summary=str(item["summary"]),
            published_at=self._parse_datetime(str(item["published_at"])),
            updated_at=self._parse_datetime(str(item["updated_at"])),
            categories=list(item["categories"]),
            primary_category=str(item["primary_category"]),
            source_url=str(item["source_url"]),
            pdf_url=str(item["pdf_url"]),
        )

    def _parse_datetime(self, value: str) -> datetime:
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)

