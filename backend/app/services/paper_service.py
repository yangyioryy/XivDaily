from __future__ import annotations

import asyncio
import json
import logging
from contextlib import nullcontext
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import desc, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.clients.arxiv_client import ArxivClient
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models.paper_record import PaperRecordModel
from app.schemas.paper import Paper, PaperListResponse, PaperQuery


logger = logging.getLogger(__name__)


@dataclass
class CacheEntry:
    created_at: float
    items: list[dict[str, object]]


@dataclass
class LoadResult:
    items: list[Paper]
    status: str
    warning: str | None = None


class PaperService:
    """论文查询服务，统一从本地论文库读取数据并输出前端所需状态。"""

    # 保留旧字段，避免现有测试或调用方直接访问时报错。
    _shared_cache: dict[tuple[str, str], CacheEntry] = {}
    _shared_inflight: dict[tuple[str, str], asyncio.Task[list[dict[str, object]]]] = {}

    def __init__(
        self,
        db: Session | None = None,
        arxiv_client: ArxivClient | None = None,
    ) -> None:
        self.settings = get_settings()
        self.db = db
        # 构造参数暂时保留，兼容旧测试注入；请求链路不再实时直连 arXiv。
        self.arxiv_client = arxiv_client or ArxivClient()

    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
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

    def _parse_json_list(self, payload: str) -> list[str]:
        parsed = json.loads(payload)
        if not isinstance(parsed, list):
            return []
        return [str(item) for item in parsed]

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

    def _build_warning(self, days: int | None, load_warning: str | None, empty_reason: str | None) -> str | None:
        if load_warning:
            return load_warning
        if empty_reason == "time_window_filtered" and days is not None:
            return f"当前 {days} 天时间窗内暂无结果，可以尝试切换到 7 天或 30 天。"
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
