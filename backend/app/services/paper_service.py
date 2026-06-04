from __future__ import annotations

import asyncio
import json
import logging
from contextlib import nullcontext
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from time import monotonic

from sqlalchemy import desc, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.clients.arxiv_client import ArxivClient, ArxivSearchResult
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models.paper_record import PaperRecordModel
from app.schemas.paper import Paper, PaperListResponse, PaperQuery


logger = logging.getLogger(__name__)


@dataclass
class CacheEntry:
    created_at: float
    result: ArxivSearchResult


@dataclass
class LoadResult:
    items: list[Paper]
    status: str
    warning: str | None = None


class PaperService:
    """论文查询服务，按查询语义选择本地论文库或实时 arXiv 搜索。"""

    # 保留旧字段，避免现有测试或调用方直接访问时报错。
    _shared_cache: dict[tuple[str, str, int], CacheEntry] = {}
    _shared_inflight: dict[tuple[str, str, int], asyncio.Task[ArxivSearchResult]] = {}
    _REMOTE_SEARCH_MAX_RESULTS_CAP = 200

    def __init__(
        self,
        db: Session | None = None,
        arxiv_client: ArxivClient | None = None,
    ) -> None:
        self.settings = get_settings()
        self.db = db
        self.arxiv_client = arxiv_client or ArxivClient()

    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        if self._should_use_remote_keyword_search(query):
            return await self._list_remote_keyword_results(query)

        with self._session_scope() as db:
            load_result = self._load_papers(db)
            keyword_filtered = self._filter_by_keyword(load_result.items, query.keyword)
            category_filtered = self._filter_by_category(keyword_filtered, query.category)
            filtered = self._filter_by_time_window(category_filtered, query.days)
            start = (query.page - 1) * query.page_size
            end = start + query.page_size
            page_items = filtered[start:end]
            empty_reason = self._resolve_empty_reason(
                keyword_filtered,
                category_filtered,
                filtered,
                load_result.status,
                query.days,
            )
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

    async def _list_remote_keyword_results(self, query: PaperQuery) -> PaperListResponse:
        keyword = (query.keyword or "").strip()
        max_results = self._remote_search_max_results(query)
        search_result = await self._search_arxiv_with_cache(query.category, keyword, max_results)
        papers = [self._arxiv_item_to_paper(item) for item in search_result.items]
        filtered = self._filter_by_category(papers, query.category)
        start = (query.page - 1) * query.page_size
        end = start + query.page_size
        page_items = filtered[start:end]
        empty_reason = self._resolve_remote_empty_reason(search_result, papers, filtered, query.category)
        return PaperListResponse(
            query=query,
            items=page_items,
            page=query.page,
            page_size=query.page_size,
            total=len(filtered),
            has_more=end < len(filtered),
            status=self._resolve_remote_response_status(search_result, filtered),
            warning=self._build_remote_warning(search_result, empty_reason),
            empty_reason=empty_reason,
        )

    async def _search_arxiv_with_cache(
        self,
        category: str | None,
        keyword: str,
        max_results: int,
    ) -> ArxivSearchResult:
        cache_key = ((category or "").strip(), keyword.lower(), max_results)
        cached = self.__class__._shared_cache.get(cache_key)
        if cached is not None and monotonic() - cached.created_at < self.settings.arxiv_cache_ttl_seconds:
            return cached.result

        inflight = self.__class__._shared_inflight.get(cache_key)
        if inflight is None:
            inflight = asyncio.create_task(self._search_arxiv_with_status(category, keyword, max_results))
            self.__class__._shared_inflight[cache_key] = inflight
            owns_task = True
        else:
            owns_task = False

        try:
            result = await inflight
            # 只缓存 arXiv 正常响应，避免限流或超时状态在 TTL 内被误认为稳定空结果。
            if owns_task and result.status == "ok":
                self.__class__._shared_cache[cache_key] = CacheEntry(created_at=monotonic(), result=result)
            return result
        finally:
            if owns_task:
                self.__class__._shared_inflight.pop(cache_key, None)

    async def _search_arxiv_with_status(
        self,
        category: str | None,
        keyword: str,
        max_results: int,
    ) -> ArxivSearchResult:
        if hasattr(self.arxiv_client, "search_with_status"):
            return await self.arxiv_client.search_with_status(category=category, keyword=keyword, max_results=max_results)
        items = await self.arxiv_client.search(category=category, keyword=keyword, max_results=max_results)
        return ArxivSearchResult(items=items)

    def _should_use_remote_keyword_search(self, query: PaperQuery) -> bool:
        return self._normalize(query.keyword) is not None and query.days is None

    def _remote_search_max_results(self, query: PaperQuery) -> int:
        requested_end = query.page * query.page_size
        desired = max(self.settings.arxiv_sync_max_results, requested_end)
        return min(desired, self._REMOTE_SEARCH_MAX_RESULTS_CAP)

    def _load_papers(self, db: Session) -> LoadResult:
        try:
            records = db.scalars(
                select(PaperRecordModel).order_by(
                    desc(PaperRecordModel.published_at),
                    desc(PaperRecordModel.updated_at),
                )
            ).all()
        except OperationalError as exc:
            if not self._recover_missing_library_table(db, exc):
                raise
            records = []

        papers = [self._to_paper(record) for record in records]
        if not papers:
            return LoadResult(
                items=[],
                status="unavailable",
                warning="本地论文库尚未同步完成，请稍后重试。",
            )

        latest_synced_at = max(self._ensure_utc(record.synced_at) for record in records)
        stale_delta = timedelta(seconds=self.settings.paper_library_stale_after_seconds)
        if datetime.now(UTC) - latest_synced_at > stale_delta:
            logger.warning("本地论文库已过期，最近一次同步时间为 %s", latest_synced_at.isoformat())
            return LoadResult(
                items=papers,
                status="stale",
                warning="本地论文库数据已过期，当前展示的是最近一次同步结果。",
            )

        return LoadResult(items=papers, status="ok")

    def _filter_by_keyword(self, papers: list[Paper], keyword: str | None) -> list[Paper]:
        normalized_keyword = self._normalize(keyword)
        if normalized_keyword is None:
            return papers

        result: list[Paper] = []
        for paper in papers:
            haystacks = [
                paper.id.lower(),
                paper.title.lower(),
                paper.summary.lower(),
                " ".join(paper.authors).lower(),
            ]
            if any(normalized_keyword in value for value in haystacks):
                result.append(paper)
        return result

    def _filter_by_category(self, papers: list[Paper], category: str | None) -> list[Paper]:
        if not category:
            return papers
        return [paper for paper in papers if category in paper.categories]

    def _filter_by_time_window(self, papers: list[Paper], days: int | None) -> list[Paper]:
        if days is None:
            return papers
        cutoff = datetime.now(UTC) - timedelta(days=days)
        return [paper for paper in papers if paper.published_at >= cutoff]

    def _to_paper(self, record: PaperRecordModel) -> Paper:
        return Paper(
            id=record.paper_id,
            title=record.title,
            authors=self._parse_json_list(record.authors_json),
            summary=record.summary,
            published_at=self._ensure_utc(record.published_at),
            updated_at=self._ensure_utc(record.updated_at),
            categories=self._parse_json_list(record.categories_json),
            primary_category=record.primary_category,
            source_url=record.source_url,
            pdf_url=record.pdf_url,
        )

    def _arxiv_item_to_paper(self, item: dict[str, object]) -> Paper:
        categories = [str(value) for value in item.get("categories", [])]
        primary_category = str(item.get("primary_category") or (categories[0] if categories else ""))
        return Paper(
            id=str(item["id"]),
            title=str(item["title"]),
            authors=[str(value) for value in item.get("authors", [])],
            summary=str(item["summary"]),
            published_at=self._parse_datetime(str(item["published_at"])),
            updated_at=self._parse_datetime(str(item["updated_at"])),
            categories=categories,
            primary_category=primary_category,
            source_url=str(item["source_url"]),
            pdf_url=str(item["pdf_url"]),
        )

    def _parse_json_list(self, payload: str) -> list[str]:
        parsed = json.loads(payload)
        if not isinstance(parsed, list):
            return []
        return [str(item) for item in parsed]

    def _parse_datetime(self, value: str) -> datetime:
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)

    def _ensure_utc(self, value: datetime) -> datetime:
        return value if value.tzinfo is not None else value.replace(tzinfo=UTC)

    def _resolve_empty_reason(
        self,
        keyword_filtered: list[Paper],
        category_filtered: list[Paper],
        filtered: list[Paper],
        load_status: str,
        days: int | None,
    ) -> str | None:
        if filtered:
            return None
        if load_status == "unavailable":
            return None
        if not keyword_filtered:
            return "no_results"
        if not category_filtered:
            return "no_results"
        return "time_window_filtered" if days is not None else "no_results"

    def _resolve_response_status(self, load_status: str, filtered: list[Paper]) -> str:
        if load_status in {"stale", "unavailable"}:
            return load_status
        return "empty" if not filtered else "ok"

    def _resolve_remote_empty_reason(
        self,
        search_result: ArxivSearchResult,
        papers: list[Paper],
        filtered: list[Paper],
        category: str | None,
    ) -> str | None:
        if filtered:
            return None
        if search_result.status == "rate_limited":
            return "rate_limited"
        if search_result.status != "ok":
            return "upstream_unavailable"
        if category and papers:
            return "category_filtered"
        return "no_results"

    def _resolve_remote_response_status(self, search_result: ArxivSearchResult, filtered: list[Paper]) -> str:
        if filtered:
            return "ok"
        if search_result.status != "ok":
            return "unavailable"
        return "empty"

    def _build_warning(self, days: int | None, load_warning: str | None, empty_reason: str | None) -> str | None:
        if load_warning:
            return load_warning
        if empty_reason == "time_window_filtered" and days is not None:
            return f"当前 {days} 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。"
        return None

    def _build_remote_warning(self, search_result: ArxivSearchResult, empty_reason: str | None) -> str | None:
        if search_result.warning:
            return search_result.warning
        if empty_reason == "category_filtered":
            return "arXiv 找到了相关论文，但当前分类没有命中。可以切换分类或清空分类后再搜索。"
        return None

    def _recover_missing_library_table(self, db: Session, exc: OperationalError) -> bool:
        if not self._is_missing_library_table_error(exc):
            db.rollback()
            return False

        db.rollback()
        PaperRecordModel.__table__.create(bind=db.get_bind(), checkfirst=True)
        return True

    def _is_missing_library_table_error(self, exc: OperationalError) -> bool:
        message = str(getattr(exc, "orig", exc)).lower()
        return "no such table" in message and PaperRecordModel.__tablename__ in message

    def _normalize(self, value: str | None) -> str | None:
        normalized = (value or "").strip().lower()
        return normalized or None

    def _session_scope(self):
        if self.db is not None:
            return nullcontext(self.db)
        return SessionLocal()
