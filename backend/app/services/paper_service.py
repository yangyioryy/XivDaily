from __future__ import annotations

import asyncio
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


@dataclass
class LoadResult:
    items: list[dict[str, object]]
    status: str
    warning: str | None = None


class PaperService:
    """论文查询服务，负责缓存、去重、时间窗过滤和分页。"""

    # FastAPI 会频繁创建服务实例，这里共享缓存才能真正跨请求限流。
    _shared_cache: dict[tuple[str, str], CacheEntry] = {}
    _shared_inflight: dict[tuple[str, str], asyncio.Task[list[dict[str, object]]]] = {}

    def __init__(self, arxiv_client: ArxivClient | None = None) -> None:
        self.settings = get_settings()
        self.arxiv_client = arxiv_client or ArxivClient()
        self._cache = self._shared_cache

    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        load_result = await self._load_raw_items(query)
        raw_items = load_result.items
        normalized = [self._to_paper(item) for item in raw_items]
        category_filtered = self._filter_by_category(normalized, query.category)
        filtered = self._filter_by_time_window(category_filtered, query.days)
        filtered = self._dedupe(filtered)
        start = (query.page - 1) * query.page_size
        end = start + query.page_size
        page_items = filtered[start:end]
        empty_reason = self._resolve_empty_reason(raw_items, category_filtered, filtered, load_result.status, query.days)
        return PaperListResponse(
            query=query,
            items=page_items,
            page=query.page,
            page_size=query.page_size,
            total=len(filtered),
            has_more=end < len(filtered),
            status=self._resolve_response_status(load_result.status, filtered),
            warning=self._build_warning(query.days, load_result.warning, empty_reason),
            empty_reason=empty_reason,
        )

    async def _load_raw_items(self, query: PaperQuery) -> LoadResult:
        normalized_keyword = self._normalize(query.keyword)
        normalized_category = self._normalize(query.category)
        cache_key = self._build_cache_key(normalized_category, normalized_keyword)
        cached = self._cache.get(cache_key)
        if cached and monotonic() - cached.created_at < self.settings.arxiv_cache_ttl_seconds:
            return LoadResult(items=cached.items, status="ok")

        max_results = max(query.page * query.page_size * 3, 100)
        # 关键词搜索先面向全 arXiv 召回，再在服务层按分类过滤，避免交叉分类论文被 cat AND all 误杀。
        request_category = None if normalized_keyword else normalized_category
        task = self._shared_inflight.get(cache_key)
        owner = False
        if task is None:
            task = asyncio.create_task(self._fetch_raw_items(request_category, normalized_keyword, max_results))
            self._shared_inflight[cache_key] = task
            owner = True
        try:
            items = await task
        except httpx.HTTPError as exc:
            if cached is not None:
                logger.warning("arXiv 请求失败，回退到过期缓存: %s", exc)
                return LoadResult(
                    items=cached.items,
                    status="stale",
                    warning="arXiv 请求失败，当前展示的是最近一次缓存结果。",
                )
            # 上游限流或网络抖动时，优先返回空列表而不是把接口直接打成 500。
            logger.warning("arXiv 请求失败且无缓存可用，返回空结果: %s", exc)
            return LoadResult(
                items=[],
                status="unavailable",
                warning="arXiv 请求暂时不可用，请稍后重试。",
            )
        finally:
            if owner and self._shared_inflight.get(cache_key) is task:
                self._shared_inflight.pop(cache_key, None)

        self._cache[cache_key] = CacheEntry(created_at=monotonic(), items=items)
        return LoadResult(items=items, status="ok")

    async def _fetch_raw_items(
        self,
        category: str | None,
        keyword: str | None,
        max_results: int,
    ) -> list[dict[str, object]]:
        return await self.arxiv_client.search(category, keyword, max_results)

    def _filter_by_category(self, papers: list[Paper], category: str | None) -> list[Paper]:
        if not category:
            return papers
        return [paper for paper in papers if category in paper.categories]

    def _filter_by_time_window(self, papers: list[Paper], days: int | None) -> list[Paper]:
        if days is None:
            return papers
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

    def _resolve_empty_reason(
        self,
        raw_items: list[dict[str, object]],
        category_filtered: list[Paper],
        filtered: list[Paper],
        load_status: str,
        days: int | None,
    ) -> str | None:
        if filtered:
            return None
        if load_status == "unavailable":
            return None
        if raw_items and not category_filtered:
            return "no_results"
        if raw_items:
            return "time_window_filtered" if days is not None else "no_results"
        return "no_results"

    def _resolve_response_status(self, load_status: str, filtered: list[Paper]) -> str:
        if load_status in {"stale", "unavailable"}:
            return load_status
        return "empty" if not filtered else "ok"

    def _build_warning(self, days: int | None, load_warning: str | None, empty_reason: str | None) -> str | None:
        if load_warning:
            return load_warning
        if empty_reason == "time_window_filtered" and days is not None:
            return f"当前 {days} 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。"
        return None

    def _build_cache_key(self, category: str | None, keyword: str | None) -> tuple[str, str]:
        if keyword:
            return ("search", keyword)
        return ("feed", category or "cs.CV")

    def _normalize(self, value: str | None) -> str | None:
        normalized = (value or "").strip()
        return normalized or None
