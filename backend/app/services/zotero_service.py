from __future__ import annotations

from datetime import UTC, datetime
from hashlib import sha1

from sqlalchemy.orm import Session

from app.clients.zotero_client import ZoteroClient
from app.models.sync_record import SyncRecordModel
from app.schemas.paper import PaperQuery
from app.schemas.zotero import BibtexExportRequest, BibtexExportResponse, ZoteroConfigStatus
from app.services.paper_service import PaperService


class ZoteroService:
    """Zotero 集成服务，负责配置校验、幂等同步、状态回写和 BibTeX 导出。"""

    def __init__(self, zotero_client: ZoteroClient | None = None, paper_service: PaperService | None = None) -> None:
        self.zotero_client = zotero_client or ZoteroClient()
        self.paper_service = paper_service or PaperService()

    def get_config_status(self) -> ZoteroConfigStatus:
        if self.zotero_client.is_configured():
            settings = self.zotero_client.settings
            return ZoteroConfigStatus(
                configured=True,
                user_id=settings.zotero_user_id,
                library_type=settings.zotero_library_type,
            )
        return ZoteroConfigStatus(
            configured=False,
            warning="未完成 Zotero User ID 或 API Key 配置。",
        )

    async def sync_paper(self, db: Session, paper_id: str) -> SyncRecordModel:
        existing = db.get(SyncRecordModel, paper_id)
        if existing and existing.status == "synced":
            return existing

        paper = await self._find_paper(paper_id)
        if paper is None:
            return self._upsert_record(db, paper_id, status="failed", message="未找到对应论文，无法同步到 Zotero。")

        if not self.zotero_client.is_configured():
            return self._upsert_record(db, paper_id, status="failed", message="未完成 Zotero 配置。")

        item_key = sha1(paper_id.encode("utf-8")).hexdigest()[:8]
        payload = {
            "itemKey": item_key,
            "data": {
                "itemType": "preprint",
                "title": paper.title,
                "abstractNote": paper.summary,
                "url": paper.source_url,
                "archiveID": paper.id,
                "libraryCatalog": "arXiv",
                "date": paper.published_at.date().isoformat(),
                "creators": [{"creatorType": "author", "name": author} for author in paper.authors],
                "tags": [{"tag": category} for category in paper.categories],
            },
        }
        try:
            response = await self.zotero_client.create_item(payload)
            item_key = self._extract_item_key(response) or item_key
            return self._upsert_record(db, paper_id, status="synced", zotero_item_key=item_key, message="同步成功。")
        except Exception as exc:  # noqa: BLE001
            return self._upsert_record(db, paper_id, status="failed", message=f"同步失败：{exc}")

    async def export_bibtex(self, request: BibtexExportRequest) -> BibtexExportResponse:
        entries: list[str] = []
        for paper_id in request.paper_ids:
            paper = await self._find_paper(paper_id)
            if paper is None:
                continue
            author_names = " and ".join(paper.authors)
            first_author = paper.authors[0].split()[-1].lower() if paper.authors else "paper"
            cite_key = f"{first_author}{paper.published_at.year}"
            entries.append(
                "\n".join(
                    [
                        f"@misc{{{cite_key},",
                        f"  title = {{{paper.title}}},",
                        f"  author = {{{author_names}}},",
                        f"  year = {{{paper.published_at.year}}},",
                        f"  howpublished = {{\\url{{{paper.source_url}}}}},",
                        f"  note = {{arXiv:{paper.id}}}",
                        "}",
                    ]
                )
            )
        content = "\n\n".join(entries)
        return BibtexExportResponse(content=content, exported_count=len(entries))

    async def _find_paper(self, paper_id: str):
        query = PaperQuery(category=None, keyword=paper_id, days=30, page=1, page_size=10)
        papers = (await self.paper_service.list_papers(query)).items
        for paper in papers:
            if paper.id == paper_id:
                return paper
        return None

    def _upsert_record(
        self,
        db: Session,
        paper_id: str,
        status: str,
        message: str,
        zotero_item_key: str | None = None,
    ) -> SyncRecordModel:
        record = db.get(SyncRecordModel, paper_id) or SyncRecordModel(paper_id=paper_id)
        record.status = status
        record.message = message
        record.zotero_item_key = zotero_item_key
        record.synced_at = datetime.now(UTC)
        db.add(record)
        db.commit()
        db.refresh(record)
        return record

    def _extract_item_key(self, response: dict[str, object]) -> str | None:
        successful = response.get("successful")
        if isinstance(successful, dict):
            for value in successful.values():
                if isinstance(value, dict):
                    return value.get("key")
        return None

