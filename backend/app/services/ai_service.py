from __future__ import annotations

import json
from datetime import UTC, datetime
from datetime import timedelta

from app.ai.llm_gateway import LlmGateway
from app.ai.prompts import build_translation_prompt, build_trend_prompt
from app.models.trend_summary_cache import TrendSummaryCacheModel
from app.schemas.ai import TranslationRequest, TranslationTask, TrendSummary, TrendSummaryItem
from app.schemas.paper import PaperQuery
from app.services.paper_service import PaperService
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session


class AiService:
    """AI 编排层，统一管理趋势摘要和摘要翻译的主流程与降级行为。"""

    def __init__(
        self,
        db: Session,
        llm_gateway: LlmGateway | None = None,
        paper_service: PaperService | None = None,
    ) -> None:
        self.db = db
        self.llm_gateway = llm_gateway or LlmGateway()
        self.paper_service = paper_service or PaperService()

    async def generate_trend_summary(self, category: str | None, days: int) -> TrendSummary:
        fixed_days = FIXED_TREND_DAYS
        cache_key, window_start, window_end = self._build_cache_window(category)
        cached = self._load_cached_summary(cache_key)
        if cached is not None:
            return cached

        paper_query = PaperQuery(category=category, keyword=None, days=fixed_days, page=1, page_size=10)
        papers = (await self.paper_service.list_papers(paper_query)).items
        snippets = [f"{paper.id} | {paper.title} | {paper.summary[:160]}" for paper in papers]
        result = await self.llm_gateway.complete(build_trend_prompt(fixed_days, category, snippets), task_name="trend_summary")
        fallback_items = self._build_fallback_trends(papers)

        if result.status == "success":
            parsed = self._parse_trend_response(result.text, fallback_items)
            summary = TrendSummary(
                category=category,
                days=fixed_days,
                generated_at=datetime.now(UTC),
                intro=parsed["intro"],
                items=parsed["items"],
                dismissible=True,
                status="success",
            )
            self._save_cache(summary, cache_key, window_start, window_end)
            return summary

        summary = TrendSummary(
            category=category,
            days=fixed_days,
            generated_at=datetime.now(UTC),
            intro="当前使用本地降级摘要，后续可在配置好模型后重试。",
            items=fallback_items,
            dismissible=True,
            status="degraded",
            warning=result.warning,
        )
        self._save_cache(summary, cache_key, window_start, window_end)
        return summary

    async def translate_summary(self, request: TranslationRequest) -> TranslationTask:
        result = await self.llm_gateway.complete(
            build_translation_prompt(request.source_summary, request.target_language),
            task_name="summary_translation",
        )
        if result.status == "success":
            return TranslationTask(
                paper_id=request.paper_id,
                status="success",
                translated_summary=result.text.strip(),
                requested_at=datetime.now(UTC),
            )

        return TranslationTask(
            paper_id=request.paper_id,
            status="degraded",
            translated_summary=self._fallback_translation(request.source_summary),
            requested_at=datetime.now(UTC),
            warning=result.warning,
        )

    def _build_fallback_trends(self, papers: list) -> list[TrendSummaryItem]:
        if not papers:
            return [
                TrendSummaryItem(
                    rank=1,
                    trend_title="暂无论文数据",
                    summary="当前筛选条件下暂无可用于生成趋势摘要的论文。",
                    representative_paper_ids=[],
                )
            ]

        items: list[TrendSummaryItem] = []
        for index, paper in enumerate(papers[:3], start=1):
            items.append(
                TrendSummaryItem(
                    rank=index,
                    trend_title=paper.title[:40],
                    summary=f"该论文属于 {paper.primary_category}，可作为当前窗口内的代表研究线索。",
                    representative_paper_ids=[paper.id],
                )
            )
        return items

    def _fallback_translation(self, source_summary: str) -> str:
        return f"模型暂不可用，当前返回原摘要作为降级结果：{source_summary}"

    def _build_cache_window(self, category: str | None) -> tuple[str, datetime, datetime]:
        window_end = datetime.now(UTC)
        window_start = window_end - timedelta(days=FIXED_TREND_DAYS)
        normalized_category = (category or "").strip()
        date_key = window_end.date().isoformat()
        cache_key = f"{normalized_category or 'all'}:{FIXED_TREND_DAYS}:{date_key}"
        return cache_key, window_start, window_end

    def _parse_trend_response(self, payload: str, fallback_items: list[TrendSummaryItem]) -> dict[str, object]:
        try:
            raw = json.loads(payload)
        except json.JSONDecodeError:
            return {
                "intro": "以下内容由大模型结合当前时间窗口内的论文生成。",
                "items": fallback_items,
            }

        raw_items = raw.get("items")
        if not isinstance(raw_items, list) or not raw_items:
            return {
                "intro": "以下内容由大模型结合当前时间窗口内的论文生成。",
                "items": fallback_items,
            }

        items: list[TrendSummaryItem] = []
        for index, item in enumerate(raw_items[:3], start=1):
            if not isinstance(item, dict):
                continue
            title = str(item.get("trend_title") or "").strip()
            summary = str(item.get("summary") or "").strip()
            paper_ids = item.get("representative_paper_ids") or []
            if not title or not summary or not isinstance(paper_ids, list):
                continue
            items.append(
                TrendSummaryItem(
                    rank=int(item.get("rank") or index),
                    trend_title=title,
                    summary=summary,
                    representative_paper_ids=[str(paper_id) for paper_id in paper_ids if str(paper_id).strip()],
                )
            )

        if not items:
            items = fallback_items

        return {
            "intro": str(raw.get("intro") or "以下内容由大模型结合当前时间窗口内的论文生成。").strip(),
            "items": items,
        }

    def _save_cache(
        self,
        summary: TrendSummary,
        cache_key: str,
        window_start: datetime,
        window_end: datetime,
    ) -> None:
        model = TrendSummaryCacheModel(
            cache_key=cache_key,
            category=summary.category or "",
            days=summary.days,
            window_start=window_start,
            window_end=window_end,
            intro=summary.intro,
            items_json=json.dumps([item.model_dump() for item in summary.items], ensure_ascii=False),
            status=summary.status,
            warning=summary.warning,
            generated_at=summary.generated_at,
        )
        try:
            self.db.merge(model)
            self.db.commit()
        except OperationalError as exc:
            # 兼容已存在旧版 SQLite 文件但尚未执行 0002 migration 的场景。
            if not self._recover_missing_cache_table(exc):
                raise
            self.db.merge(model)
            self.db.commit()

    def _cache_model_to_summary(self, model: TrendSummaryCacheModel) -> TrendSummary:
        items = [TrendSummaryItem.model_validate(item) for item in json.loads(model.items_json)]
        return TrendSummary(
            category=model.category or None,
            days=model.days,
            generated_at=model.generated_at.replace(tzinfo=UTC) if model.generated_at.tzinfo is None else model.generated_at,
            intro=model.intro,
            items=items,
            dismissible=True,
            status=model.status,
            warning=model.warning,
        )

    def _load_cached_summary(self, cache_key: str) -> TrendSummary | None:
        try:
            cached = self.db.get(TrendSummaryCacheModel, cache_key)
        except OperationalError as exc:
            # 老库缺表时先补建缓存表，再回到正常缓存流程。
            if not self._recover_missing_cache_table(exc):
                raise
            cached = self.db.get(TrendSummaryCacheModel, cache_key)
        return self._cache_model_to_summary(cached) if cached is not None else None

    def _recover_missing_cache_table(self, exc: OperationalError) -> bool:
        if not self._is_missing_cache_table_error(exc):
            self.db.rollback()
            return False

        self.db.rollback()
        bind = self.db.get_bind()
        TrendSummaryCacheModel.__table__.create(bind=bind, checkfirst=True)
        return True

    def _is_missing_cache_table_error(self, exc: OperationalError) -> bool:
        message = str(getattr(exc, "orig", exc)).lower()
        return "no such table" in message and TrendSummaryCacheModel.__tablename__ in message


FIXED_TREND_DAYS = 3
