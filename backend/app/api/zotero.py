from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.sync_record import SyncRecordModel
from app.schemas.zotero import BibtexExportRequest, BibtexExportResponse, ZoteroConfigStatus
from app.services.zotero_service import ZoteroService

router = APIRouter(prefix="/zotero", tags=["zotero"])


def get_zotero_service() -> ZoteroService:
    return ZoteroService()


@router.get("/config/status", response_model=ZoteroConfigStatus)
def get_config_status(service: ZoteroService = Depends(get_zotero_service)) -> ZoteroConfigStatus:
    return service.get_config_status()


@router.post("/sync/{paper_id}", response_model=dict)
async def sync_paper(
    paper_id: str,
    db: Session = Depends(get_db),
    service: ZoteroService = Depends(get_zotero_service),
) -> dict[str, object]:
    record: SyncRecordModel = await service.sync_paper(db, paper_id)
    return {
        "paper_id": record.paper_id,
        "status": record.status,
        "zotero_item_key": record.zotero_item_key,
        "message": record.message,
        "synced_at": record.synced_at,
    }


@router.post("/exports/bibtex", response_model=BibtexExportResponse)
async def export_bibtex(
    request: BibtexExportRequest,
    service: ZoteroService = Depends(get_zotero_service),
) -> BibtexExportResponse:
    return await service.export_bibtex(request)

