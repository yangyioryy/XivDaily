from fastapi import APIRouter, Depends, Query

from app.schemas.paper import PaperListResponse, PaperQuery
from app.services.paper_service import PaperService

router = APIRouter(prefix="/papers", tags=["papers"])


def get_paper_service() -> PaperService:
    return PaperService()


@router.get("", response_model=PaperListResponse)
async def list_papers(
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    days: int = Query(default=7, ge=1, le=30),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, ge=1, le=50, alias="pageSize"),
    service: PaperService = Depends(get_paper_service),
) -> PaperListResponse:
    query = PaperQuery(keyword=keyword, category=category, days=days, page=page, page_size=page_size)
    return await service.list_papers(query)

