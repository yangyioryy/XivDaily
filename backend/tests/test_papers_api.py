from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.api.papers import get_paper_service
from app.main import app
from app.schemas.paper import Paper, PaperListResponse, PaperQuery


class FakePaperService:
    def __init__(self) -> None:
        self.queries: list[PaperQuery] = []

    async def list_papers(self, query: PaperQuery) -> PaperListResponse:
        self.queries.append(query)
        now = datetime.now(UTC)
        return PaperListResponse(
            query=query,
            items=[
                Paper(
                    id="2401.00001",
                    title="Mock Paper",
                    authors=["A. Author"],
                    summary="Summary",
                    published_at=now,
                    updated_at=now,
                    categories=["cs.CV"],
                    primary_category="cs.CV",
                    source_url="https://arxiv.org/abs/2401.00001",
                    pdf_url="https://arxiv.org/pdf/2401.00001",
                )
            ],
            page=query.page,
            page_size=query.page_size,
            total=1,
            has_more=False,
            status="ok",
            warning=None,
            empty_reason=None,
        )


def test_papers_api_returns_paginated_response() -> None:
    fake_service = FakePaperService()
    app.dependency_overrides[get_paper_service] = lambda: fake_service
    client = TestClient(app)

    response = client.get("/papers?category=cs.CV&page=1&pageSize=10")

    app.dependency_overrides.clear()
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == "2401.00001"
    assert body["query"]["category"] == "cs.CV"
    assert body["query"]["days"] == 7
    assert body["status"] == "ok"
    assert body["warning"] is None
    assert body["empty_reason"] is None
    assert fake_service.queries[0].days == 7


def test_papers_api_keyword_search_omits_days_by_default() -> None:
    fake_service = FakePaperService()
    app.dependency_overrides[get_paper_service] = lambda: fake_service
    client = TestClient(app)

    response = client.get("/papers?keyword=omibench&category=cs.AI&page=1&pageSize=10")

    app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json()["query"]["days"] is None
    assert fake_service.queries[0].keyword == "omibench"
    assert fake_service.queries[0].category == "cs.AI"
    assert fake_service.queries[0].days is None
