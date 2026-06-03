from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from sqlalchemy import desc, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.clients.arxiv_client import ArxivClient
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models.paper_record import PaperRecordModel


logger = logging.getLogger(__name__)


class PaperSyncService:
    """同步 arXiv 论文元数据到本地数据库。"""

    def __init__(
        self,
        session_factory: Callable[[], Session] | None = None,
        arxiv_client: ArxivClient | None = None,
    ) -> None:
        self.settings = get_settings()
        self.session_factory = session_factory or SessionLocal
        self.arxiv_client = arxiv_client or ArxivClient()

    async def run_periodic(self, stop_event: asyncio.Event) -> None:
        """先立即同步一轮，再按配置周期持续同步。"""
        while not stop_event.is_set():
            try:
                await self.sync_once()
            except Exception:  # noqa: BLE001
                logger.exception("论文同步任务执行失败")

            try:
                await asyncio.wait_for(stop_event.wait(), timeout=self.settings.arxiv_sync_interval_seconds)
            except TimeoutError:
                continue

    async def sync_once(self) -> dict[str, int]:
        """执行一轮同步，并返回写入、清理和失败分类统计。"""
        categories = self.settings.arxiv_sync_category_list
        if not categories:
            logger.warning("未配置任何 arXiv 同步分类，本轮同步已跳过")
            return {"upserted": 0, "deleted": 0, "failed": 0}

        cutoff = datetime.now(UTC) - timedelta(days=self.settings.arxiv_sync_window_days)
        upserted = 0
        deleted = 0
        failed = 0
        successful_categories: list[str] = []

        with self.session_factory() as db:
            for category in categories:
                try:
                    items = await self.arxiv_client.search(
                        category=category,
                        keyword=None,
                        max_results=self.settings.arxiv_sync_max_results,
                    )
                    for item in items:
                        published_at = self._parse_datetime(str(item["published_at"]))
                        if published_at < cutoff:
                            continue
                        self._upsert_record(db, item, published_at)
                        upserted += 1
                    db.commit()
                    successful_categories.append(category)
                except Exception:  # noqa: BLE001
                    failed += 1
                    db.rollback()
                    logger.exception("arXiv 分类同步失败。category=%s", category)
                    continue

            if successful_categories:
                deleted = self._cleanup_records(db, successful_categories)
                db.commit()

        logger.info(
            "论文同步完成。upserted=%s deleted=%s failed=%s categories=%s",
            upserted,
            deleted,
            failed,
            ",".join(categories),
        )
        return {"upserted": upserted, "deleted": deleted, "failed": failed}

    def _upsert_record(
        self,
        db: Session,
        item: dict[str, object],
        published_at: datetime,
    ) -> None:
        record = db.get(PaperRecordModel, str(item["id"]))
        now = datetime.now(UTC)
        if record is None:
            record = PaperRecordModel(paper_id=str(item["id"]))
            db.add(record)

        try:
            record.title = str(item["title"])
            record.authors_json = json.dumps(list(item["authors"]), ensure_ascii=False)
            record.summary = str(item["summary"])
            record.published_at = published_at
            record.updated_at = self._parse_datetime(str(item["updated_at"]))
            record.categories_json = json.dumps(list(item["categories"]), ensure_ascii=False)
            record.primary_category = str(item["primary_category"])
            record.source_url = str(item["source_url"])
            record.pdf_url = str(item["pdf_url"])
            record.synced_at = now
        except OperationalError as exc:
            if not self._recover_missing_table(db, exc):
                raise
            self._upsert_record(db, item, published_at)

    def _cleanup_records(self, db: Session, categories: list[str]) -> int:
        deleted = 0
        retention_cutoff = datetime.now(UTC) - timedelta(days=self.settings.paper_library_retention_days)
        stale_records = db.scalars(
            select(PaperRecordModel).where(
                PaperRecordModel.published_at < retention_cutoff,
                PaperRecordModel.primary_category.in_(categories),
            )
        ).all()
        for record in stale_records:
            db.delete(record)
            deleted += 1
        db.flush()

        limit = self.settings.paper_library_max_papers_per_category
        for category in categories:
            rows = db.scalars(
                select(PaperRecordModel)
                .where(PaperRecordModel.primary_category == category)
                .order_by(desc(PaperRecordModel.published_at), desc(PaperRecordModel.updated_at))
            ).all()
            for record in rows[limit:]:
                db.delete(record)
                deleted += 1
        return deleted

    def _recover_missing_table(self, db: Session, exc: OperationalError) -> bool:
        if not self._is_missing_table_error(exc):
            db.rollback()
            return False

        db.rollback()
        PaperRecordModel.__table__.create(bind=db.get_bind(), checkfirst=True)
        return True

    def _is_missing_table_error(self, exc: OperationalError) -> bool:
        message = str(getattr(exc, "orig", exc)).lower()
        return "no such table" in message and PaperRecordModel.__tablename__ in message

    def _parse_datetime(self, value: str) -> datetime:
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)
