from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.zotero import BibtexExportRequest, BibtexExportResponse, ZoteroConfigStatus, ZoteroSyncResult
from app.services.zotero_service import ZoteroService

router = APIRouter(prefix="/zotero", tags=["zotero"])


def get_zotero_service() -> ZoteroService:
    return ZoteroService()


@router.get("/config/status", response_model=ZoteroConfigStatus)
async def get_config_status(service: ZoteroService = Depends(get_zotero_service)) -> ZoteroConfigStatus:
    return await service.get_config_status()


@router.post("/sync/{paper_id}", response_model=ZoteroSyncResult)
async def sync_paper(
    paper_id: str,
    db: Session = Depends(get_db),
    service: ZoteroService = Depends(get_zotero_service),
) -> ZoteroSyncResult:
    return await service.sync_paper(db, paper_id)


@router.post("/exports/bibtex", response_model=BibtexExportResponse)
async def export_bibtex(
    request: BibtexExportRequest,
    service: ZoteroService = Depends(get_zotero_service),
) -> BibtexExportResponse:
    return await service.export_bibtex(request)
