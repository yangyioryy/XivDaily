from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.api.ai import get_ai_service
from app.main import app
from app.schemas.ai import PaperChatResponse, PaperChatUsedPaper, TranslationTask, TrendSummary, TrendSummaryItem


class FakeAiService:
    async def generate_trend_summary(self, category: str | None, days: int) -> TrendSummary:
        return TrendSummary(
            category=category,
            days=3,
            generated_at=datetime.now(UTC),
            intro="mock",
            items=[
                TrendSummaryItem(
                    rank=1,
                    trend_title="📊 Mock Trend",
                    summary="Mock Summary",
                    representative_paper_ids=["2401.00001"],
                )
            ],
            dismissible=True,
            status="success",
        )

    async def translate_summary(self, request) -> TranslationTask:
        return TranslationTask(
            paper_id=request.paper_id,
            status="success",
            translated_summary="翻译结果",
            requested_at=datetime.now(UTC),
        )

    async def chat_with_papers(self, request) -> PaperChatResponse:
        return PaperChatResponse(
            answer="对话结果",
            status="success",
            created_at=datetime.now(UTC),
            used_papers=[
                PaperChatUsedPaper(
                    paper_id=request.papers[0].paper_id,
                    title=request.papers[0].title,
                    status="full_text",
                    context_chars=128,
                )
            ],
        )


def test_trend_summary_api_returns_payload() -> None:
    app.dependency_overrides[get_ai_service] = lambda: FakeAiService()
    client = TestClient(app)

    response = client.get("/summaries/trends?category=cs.CV&days=30")

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["days"] == 3
    assert response.json()["items"][0]["trend_title"] == "📊 Mock Trend"


def test_translation_api_returns_payload() -> None:
    app.dependency_overrides[get_ai_service] = lambda: FakeAiService()
    client = TestClient(app)

    response = client.post(
        "/translations",
        json={"paper_id": "2401.00001", "source_summary": "summary", "target_language": "zh-CN"},
    )

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["translated_summary"] == "翻译结果"


def test_paper_chat_api_returns_payload() -> None:
    app.dependency_overrides[get_ai_service] = lambda: FakeAiService()
    client = TestClient(app)

    response = client.post(
        "/paper-chat/messages",
        json={
            "papers": [
                {
                    "paper_id": "2401.00001",
                    "title": "Mock Paper",
                    "summary": "summary",
                    "pdf_url": "https://arxiv.org/pdf/2401.00001",
                }
            ],
            "messages": [{"role": "user", "content": "核心贡献是什么？"}],
        },
    )

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["answer"] == "对话结果"
    assert response.json()["used_papers"][0]["status"] == "full_text"
