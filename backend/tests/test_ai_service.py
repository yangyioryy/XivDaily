from datetime import UTC, datetime

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.ai.llm_gateway import LlmResult
from app.db.base import Base
from app.models.trend_summary_cache import TrendSummaryCacheModel
from app.schemas.ai import TranslationRequest
from app.schemas.paper import Paper, PaperListResponse, PaperQuery
from app.services.ai_service import AiService


class FakeGateway:
    def __init__(self, status: str, text: str = "", warning: str | None = None) -> None:
        self.status = status
        self.text = text
        self.warning = warning
        self.calls = 0

    async def complete(self, prompt: str, task_name: str) -> LlmResult:
        self.calls += 1
        self.last_prompt = prompt
        return LlmResult(text=self.text, status=self.status, warning=self.warning)


class FakePaperService:
    def __init__(self) -> None:
        self.requests: list[PaperQuery] = []

    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        self.requests.append(query)
        now = datetime.now(UTC)
        papers = [
            Paper(
                id=f"2401.000{index}",
                title=f"Vision Trend {index}",
                authors=["A. Author"],
                summary="A paper about vision trends. " * 10,
                published_at=now,
                updated_at=now,
                categories=["cs.CV"],
                primary_category="cs.CV",
                source_url=f"https://arxiv.org/abs/2401.000{index}",
                pdf_url=f"https://arxiv.org/pdf/2401.000{index}",
            )
            for index in range(1, 10)
        ]
        return PaperListResponse(query=query, items=papers, page=1, page_size=query.page_size, total=len(papers), has_more=False)


def build_session() -> Session:
    engine = create_engine("sqlite:///:memory:", future=True)
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine, class_=Session, autoflush=False, autocommit=False)()


def build_session_without_trend_cache() -> Session:
    engine = create_engine("sqlite:///:memory:", future=True)
    tables = [table for table in Base.metadata.sorted_tables if table.name != TrendSummaryCacheModel.__tablename__]
    Base.metadata.create_all(bind=engine, tables=tables)
    return sessionmaker(bind=engine, class_=Session, autoflush=False, autocommit=False)()


@pytest.mark.anyio("asyncio")
async def test_generate_trend_summary_degrades_without_model() -> None:
    db = build_session()
    paper_service = FakePaperService()
    service = AiService(db=db, llm_gateway=FakeGateway(status="degraded", warning="no key"), paper_service=paper_service)

    result = await service.generate_trend_summary("cs.CV", 3)

    assert result.status == "degraded"
    assert result.warning == "no key"
    assert result.items[0].representative_paper_ids == ["2401.0001"]
    assert paper_service.requests[0].days == 3
    assert paper_service.requests[0].page_size == 8


@pytest.mark.anyio("asyncio")
async def test_translate_summary_returns_fallback_when_model_unavailable() -> None:
    service = AiService(
        db=build_session(),
        llm_gateway=FakeGateway(status="degraded", warning="timeout"),
        paper_service=FakePaperService(),
    )

    result = await service.translate_summary(
        TranslationRequest(paper_id="2401.00001", source_summary="Original summary", target_language="zh-CN")
    )

    assert result.status == "degraded"
    assert "Original summary" in result.translated_summary
    assert result.warning == "timeout"


@pytest.mark.anyio("asyncio")
async def test_generate_trend_summary_hits_cache_without_second_llm_call() -> None:
    db = build_session()
    gateway = FakeGateway(
        status="success",
        text='{"intro":"AI 总览","items":[{"rank":1,"trend_title":"📈 视觉扩散","summary":"关注扩散式视觉生成。","representative_paper_ids":["2401.00001"]}]}',
    )
    paper_service = FakePaperService()
    service = AiService(db=db, llm_gateway=gateway, paper_service=paper_service)

    first = await service.generate_trend_summary("cs.CV", 30)
    second = await service.generate_trend_summary("cs.CV", 1)

    assert first.status == "success"
    assert first.intro == "AI 总览"
    assert first.items[0].trend_title == "📈 视觉扩散"
    assert second.items[0].trend_title == "📈 视觉扩散"
    assert gateway.calls == 1
    assert len(paper_service.requests) == 1
    assert db.get(TrendSummaryCacheModel, next(iter([row.cache_key for row in db.query(TrendSummaryCacheModel).all()]))) is not None


@pytest.mark.anyio("asyncio")
async def test_generate_trend_summary_truncates_prompt_input() -> None:
    db = build_session()
    gateway = FakeGateway(status="degraded", warning="no key")
    paper_service = FakePaperService()
    service = AiService(db=db, llm_gateway=gateway, paper_service=paper_service)

    await service.generate_trend_summary("cs.CV", 3)

    prompt = gateway.last_prompt
    assert "2401.0008" in prompt
    assert "2401.0009" not in prompt
    assert "cs.CV" in prompt
    assert "A paper about vision trends. " * 5 not in prompt


@pytest.mark.anyio("asyncio")
async def test_generate_trend_summary_recovers_when_cache_table_is_missing() -> None:
    db = build_session_without_trend_cache()
    paper_service = FakePaperService()
    service = AiService(db=db, llm_gateway=FakeGateway(status="degraded", warning="no key"), paper_service=paper_service)

    result = await service.generate_trend_summary("cs.CV", 3)
    cached_rows = db.query(TrendSummaryCacheModel).all()

    assert result.status == "degraded"
    assert len(cached_rows) == 1
    assert cached_rows[0].cache_key.startswith("cs.CV:3:")
