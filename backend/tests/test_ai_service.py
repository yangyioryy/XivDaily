from datetime import UTC, datetime

import pytest

from app.ai.llm_gateway import LlmResult
from app.schemas.ai import TranslationRequest
from app.schemas.paper import Paper, PaperListResponse, PaperQuery
from app.services.ai_service import AiService


class FakeGateway:
    def __init__(self, status: str, text: str = "", warning: str | None = None) -> None:
        self.status = status
        self.text = text
        self.warning = warning

    async def complete(self, prompt: str, task_name: str) -> LlmResult:
        return LlmResult(text=self.text, status=self.status, warning=self.warning)


class FakePaperService:
    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        now = datetime.now(UTC)
        paper = Paper(
            id="2401.00001",
            title="Vision Trend",
            authors=["A. Author"],
            summary="A paper about vision trends.",
            published_at=now,
            updated_at=now,
            categories=["cs.CV"],
            primary_category="cs.CV",
            source_url="https://arxiv.org/abs/2401.00001",
            pdf_url="https://arxiv.org/pdf/2401.00001",
        )
        return PaperListResponse(query=query, items=[paper], page=1, page_size=10, total=1, has_more=False)


@pytest.mark.anyio("asyncio")
async def test_generate_trend_summary_degrades_without_model() -> None:
    service = AiService(llm_gateway=FakeGateway(status="degraded", warning="no key"), paper_service=FakePaperService())

    result = await service.generate_trend_summary("cs.CV", 3)

    assert result.status == "degraded"
    assert result.warning == "no key"
    assert result.items[0].representative_paper_ids == ["2401.00001"]


@pytest.mark.anyio("asyncio")
async def test_translate_summary_returns_fallback_when_model_unavailable() -> None:
    service = AiService(llm_gateway=FakeGateway(status="degraded", warning="timeout"), paper_service=FakePaperService())

    result = await service.translate_summary(
        TranslationRequest(paper_id="2401.00001", source_summary="Original summary", target_language="zh-CN")
    )

    assert result.status == "degraded"
    assert "Original summary" in result.translated_summary
    assert result.warning == "timeout"

