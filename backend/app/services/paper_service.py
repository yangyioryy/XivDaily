from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from time import monotonic

import httpx

from app.clients.arxiv_client import ArxivClient
from app.core.config import get_settings
from app.schemas.paper import Paper, PaperListResponse, PaperQuery


logger = logging.getLogger(__name__)


@dataclass
class CacheEntry:
    created_at: float
    items: list[dict[str, object]]


class PaperService:
    """论文查询服务，负责缓存、去重、时间窗过滤和分页。"""

    # FastAPI 会频繁创建服务实例，这里共享缓存才能真正跨请求限流。
    _shared_cache: dict[tuple[str | None, str | None], CacheEntry] = {}

    def __init__(self, arxiv_client: ArxivClient | None = None) -> None:
        self.settings = get_settings()
        self.arxiv_client = arxiv_client or ArxivClient()
        self._cache = self._shared_cache

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

        max_results = max(query.page * query.page_size * 3, 100)
        try:
            items = await self.arxiv_client.search(query.category, query.keyword, max_results)
        except httpx.HTTPError as exc:
            if cached is not None:
                logger.warning("arXiv 请求失败，回退到过期缓存: %s", exc)
                return cached.items
            # 上游限流或网络抖动时，优先返回空列表而不是把接口直接打成 500。
            logger.warning("arXiv 请求失败且无缓存可用，返回空结果: %s", exc)
            return []

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
