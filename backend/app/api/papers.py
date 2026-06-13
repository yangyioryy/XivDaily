from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.paper import PaperListResponse, PaperQuery, PaperSyncResponse
from app.services.paper_service import PaperService
from app.services.paper_sync_service import PaperSyncService

router = APIRouter(prefix="/papers", tags=["papers"])


def get_paper_service(db: Session = Depends(get_db)) -> PaperService:
    return PaperService(db=db)


def get_paper_sync_service() -> PaperSyncService:
    return PaperSyncService()


@router.get("", response_model=PaperListResponse)
async def list_papers(
    keyword: str | None = Query(default=None),
    category: str | None = Query(default=None),
    days: int | None = Query(default=None, ge=1, le=30),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, ge=1, le=50, alias="pageSize"),
    service: PaperService = Depends(get_paper_service),
) -> PaperListResponse:
    effective_days = days if days is not None else (None if keyword else 7)
    query = PaperQuery(keyword=keyword, category=category, days=effective_days, page=page, page_size=page_size)
    return await service.list_papers(query)


@router.post("/sync", response_model=PaperSyncResponse)
async def sync_papers(service: PaperSyncService = Depends(get_paper_sync_service)) -> PaperSyncResponse:
    # 手动触发只执行一轮同步，复用后台任务的写库逻辑，避免维护两套流程。
    result = await service.sync_once()
    return PaperSyncResponse(**result)
