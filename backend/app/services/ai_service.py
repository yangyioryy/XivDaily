from __future__ import annotations

import json
from datetime import UTC, datetime
from datetime import timedelta

from app.ai.llm_gateway import LlmGateway
from app.ai.prompts import build_paper_chat_messages, build_translation_prompt, build_trend_prompt
from app.core.config import get_settings
from app.models.trend_summary_cache import TrendSummaryCacheModel
from app.schemas.ai import PaperChatRequest, PaperChatResponse, PaperChatUsedPaper, TranslationRequest, TranslationTask, TrendSummary, TrendSummaryItem
from app.schemas.paper import PaperQuery
from app.services.paper_service import PaperService
from app.services.paper_text_service import PaperTextResult, PaperTextService
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session


class AiService:
    """AI 编排层，统一管理趋势摘要和摘要翻译的主流程与降级行为。"""

    def __init__(
        self,
        db: Session,
        llm_gateway: LlmGateway | None = None,
        paper_service: PaperService | None = None,
        paper_text_service: PaperTextService | None = None,
    ) -> None:
        self.db = db
        self.settings = get_settings()
        self.llm_gateway = llm_gateway or LlmGateway()
        self.paper_service = paper_service or PaperService()
        self.paper_text_service = paper_text_service or PaperTextService()

    async def generate_trend_summary(self, category: str | None, days: int) -> TrendSummary:
        fixed_days = FIXED_TREND_DAYS
        cache_key, window_start, window_end = self._build_cache_window(category)
        cached = self._load_cached_summary(cache_key)
        if cached is not None and self._should_use_cached_summary(cached):
            return cached

        paper_query = PaperQuery(category=category, keyword=None, days=fixed_days, page=1, page_size=TREND_MAX_PAPERS)
        papers = (await self.paper_service.list_papers(paper_query)).items
        snippets = [
            f"{paper.id} | {paper.title} | {paper.primary_category} | {paper.summary[:TREND_SUMMARY_CHARS]}"
            for paper in papers[:TREND_MAX_PAPERS]
        ]
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

    async def chat_with_papers(self, request: PaperChatRequest) -> PaperChatResponse:
        text_results = [await self.paper_text_service.extract_text(paper) for paper in request.papers]
        used_papers: list[PaperChatUsedPaper] = []
        paper_contexts: list[str] = []
        for paper, result in zip(request.papers, text_results, strict=True):
            context = result.text[: self.settings.paper_chat_context_chars_per_paper]
            used_papers.append(
                PaperChatUsedPaper(
                    paper_id=result.paper_id,
                    title=result.title,
                    status=result.status,
                    context_chars=len(context),
                    warning=result.warning,
                )
            )
            if context or paper.source_url or paper.pdf_url:
                # 每篇论文独立截断，同时保留 arXiv 链接，方便具备检索能力的模型补充查看原文。
                paper_contexts.append(self._build_paper_chat_context(paper, result, context))

        if not paper_contexts:
            return PaperChatResponse(
                answer="没有可用于对话的论文全文或摘要内容，请重新选择带有 arXiv PDF 的收藏论文。",
                status="degraded",
                created_at=datetime.now(UTC),
                used_papers=used_papers,
                warning="未能读取任何论文上下文。",
            )

        messages = build_paper_chat_messages(paper_contexts, [message.model_dump() for message in request.messages])
        result = await self.llm_gateway.chat(messages, task_name="paper_chat")
        context_warnings = [paper.warning for paper in used_papers if paper.warning]
        context_warning = "；".join(context_warnings) if context_warnings else None

        if result.status == "success":
            return PaperChatResponse(
                answer=result.text.strip(),
                status="degraded" if context_warning else "success",
                created_at=datetime.now(UTC),
                used_papers=used_papers,
                warning=context_warning,
            )

        return PaperChatResponse(
            answer=self._fallback_paper_chat_answer(request, used_papers),
            status="degraded",
            created_at=datetime.now(UTC),
            used_papers=used_papers,
            warning=result.warning or context_warning,
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

    def _fallback_paper_chat_answer(self, request: PaperChatRequest, used_papers: list[PaperChatUsedPaper]) -> str:
        selected_titles = "、".join(paper.title for paper in used_papers if paper.context_chars > 0)
        last_question = next((message.content for message in reversed(request.messages) if message.role == "user"), "")
        return (
            "模型暂不可用，暂时无法完成全文问答。"
            f"已读取的论文材料包括：{selected_titles or '无'}。"
            f"你刚才的问题是：{last_question}"
        )

    def _build_paper_chat_context(self, paper: PaperChatPaper, result: PaperTextResult, context: str) -> str:
        source_url = paper.source_url or self._derive_abs_url(paper.pdf_url)
        local_context = context or "本地暂未提取到可用全文或摘要；如当前模型支持联网检索，请优先查看上方 arXiv 链接。"
        return (
            f"论文 ID：{result.paper_id}\n"
            f"标题：{result.title}\n"
            f"arXiv 页面：{source_url or '未提供'}\n"
            f"PDF 链接：{paper.pdf_url or '未提供'}\n"
            f"上下文来源：{result.status}\n"
            f"内容：\n{local_context}"
        )

    def _derive_abs_url(self, pdf_url: str) -> str | None:
        if "/pdf/" not in pdf_url:
            return None
        return pdf_url.replace("/pdf/", "/abs/", 1)

    def _should_use_cached_summary(self, cached: TrendSummary) -> bool:
        if cached.status == "success":
            return True
        # 降级摘要只在模型仍未配置时复用；配置恢复后需要重新请求模型，避免一直显示旧降级文案。
        return not bool(self.settings.llm_api_key and self.settings.llm_model and self.settings.llm_base_url)

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
TREND_MAX_PAPERS = 8
TREND_SUMMARY_CHARS = 100
