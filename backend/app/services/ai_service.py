from __future__ import annotations

from datetime import UTC, datetime

from app.ai.llm_gateway import LlmGateway
from app.ai.prompts import build_translation_prompt, build_trend_prompt
from app.schemas.ai import TranslationRequest, TranslationTask, TrendSummary, TrendSummaryItem
from app.schemas.paper import PaperQuery
from app.services.paper_service import PaperService


class AiService:
    """AI 编排层，统一管理趋势摘要和摘要翻译的主流程与降级行为。"""

    def __init__(self, llm_gateway: LlmGateway | None = None, paper_service: PaperService | None = None) -> None:
        self.llm_gateway = llm_gateway or LlmGateway()
        self.paper_service = paper_service or PaperService()

    async def generate_trend_summary(self, category: str | None, days: int) -> TrendSummary:
        paper_query = PaperQuery(category=category, keyword=None, days=days, page=1, page_size=10)
        papers = (await self.paper_service.list_papers(paper_query)).items
        snippets = [f"{paper.id} | {paper.title} | {paper.summary[:160]}" for paper in papers]
        result = await self.llm_gateway.complete(build_trend_prompt(days, category, snippets), task_name="trend_summary")
        items = self._build_fallback_trends(papers)

        if result.status == "success":
            return TrendSummary(
                category=category,
                days=days,
                generated_at=datetime.now(UTC),
                intro="以下内容由大模型结合当前时间窗口内的论文生成。",
                items=items,
                dismissible=True,
                status="success",
            )

        return TrendSummary(
            category=category,
            days=days,
            generated_at=datetime.now(UTC),
            intro="当前使用本地降级摘要，后续可在配置好模型后重试。",
            items=items,
            dismissible=True,
            status="degraded",
            warning=result.warning,
        )

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

