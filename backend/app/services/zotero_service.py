from __future__ import annotations

from datetime import UTC, datetime
from hashlib import sha1

from sqlalchemy.orm import Session

from app.clients.zotero_client import ZoteroClient
from app.models.sync_record import SyncRecordModel
from app.schemas.paper import PaperQuery
from app.schemas.zotero import BibtexExportRequest, BibtexExportResponse, ZoteroConfigStatus, ZoteroSyncResult
from app.services.paper_service import PaperService


class ZoteroService:
    """Zotero 集成服务，负责配置校验、幂等同步、状态回写和 BibTeX 导出。"""

    def __init__(self, zotero_client: ZoteroClient | None = None, paper_service: PaperService | None = None) -> None:
        self.zotero_client = zotero_client or ZoteroClient()
        self.paper_service = paper_service or PaperService()

    async def get_config_status(self) -> ZoteroConfigStatus:
        target_collection_name = self.zotero_client.target_collection_name
        if self.zotero_client.is_configured():
            settings = self.zotero_client.settings
            try:
                # 设置页与实际同步都依赖同一个归档集合，这里直接保证集合可用。
                target_collection = await self._ensure_target_collection()
            except Exception as exc:  # noqa: BLE001
                return ZoteroConfigStatus(
                    configured=True,
                    user_id=settings.zotero_user_id,
                    library_type=settings.zotero_library_type,
                    target_collection_name=target_collection_name,
                    target_collection_status="error",
                    warning=f"Zotero 归档集合检查失败：{exc}",
                )
            return ZoteroConfigStatus(
                configured=True,
                user_id=settings.zotero_user_id,
                library_type=settings.zotero_library_type,
                target_collection_name=str(target_collection["name"]),
                target_collection_key=str(target_collection["key"]),
                target_collection_status="created" if bool(target_collection["created"]) else "ready",
            )
        return ZoteroConfigStatus(
            configured=False,
            target_collection_name=target_collection_name,
            target_collection_status="not_configured",
            warning="未完成 Zotero User ID 或 API Key 配置。",
        )

    async def sync_paper(self, db: Session, paper_id: str) -> ZoteroSyncResult:
        existing = db.get(SyncRecordModel, paper_id)
        if existing and existing.status == "synced":
            return await self._reconcile_existing_synced_record(db, existing)

        paper = await self._find_paper(paper_id)
        if paper is None:
            record = self._upsert_record(db, paper_id, status="failed", message="未找到对应论文，无法同步到 Zotero。")
            return self._build_sync_result(
                record=record,
                target_collection={"name": self.zotero_client.target_collection_name, "key": None, "created": False},
                target_collection_status="error",
                visibility_status="not_checked",
                visibility_message="未找到论文，未发起远端同步。",
            )

        if not self.zotero_client.is_configured():
            record = self._upsert_record(db, paper_id, status="failed", message="未完成 Zotero 配置。")
            return self._build_sync_result(
                record=record,
                target_collection={"name": self.zotero_client.target_collection_name, "key": None, "created": False},
                target_collection_status="not_configured",
                visibility_status="not_checked",
                visibility_message="配置未完成，未发起远端同步。",
            )

        try:
            target_collection = await self._ensure_target_collection()
        except Exception as exc:  # noqa: BLE001
            record = self._upsert_record(db, paper_id, status="failed", message=f"准备 Zotero 归档集合失败：{exc}")
            return self._build_sync_result(
                record=record,
                target_collection={"name": self.zotero_client.target_collection_name, "key": None, "created": False},
                target_collection_status="error",
                visibility_status="not_checked",
                visibility_message=f"集合准备失败：{exc}",
            )

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
                "collections": [str(target_collection["key"])],
            },
        }
        try:
            response = await self.zotero_client.create_item(payload)
            item_key = self._extract_item_key(response) or item_key
            visibility = await self._verify_item_visibility(item_key, str(target_collection["key"]))
            if visibility["status"] == "missing_from_collection":
                visibility = await self._repair_item_collection_membership(item_key, str(target_collection["key"]))
            message = "同步成功，已归档到目标集合。" if visibility["status"] == "verified" else "同步请求已提交，但条目暂未在目标集合中确认可见。"
            record = self._upsert_record(db, paper_id, status="synced", zotero_item_key=item_key, message=message)
            return self._build_sync_result(
                record=record,
                target_collection=target_collection,
                target_collection_status="created" if bool(target_collection["created"]) else "ready",
                visibility_status=str(visibility["status"]),
                visibility_message=str(visibility["message"]),
            )
        except Exception as exc:  # noqa: BLE001
            record = self._upsert_record(db, paper_id, status="failed", message=f"同步失败：{exc}")
            return self._build_sync_result(
                record=record,
                target_collection=target_collection,
                target_collection_status="created" if bool(target_collection["created"]) else "ready",
                visibility_status="not_checked",
                visibility_message=f"远端创建条目失败：{exc}",
            )

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

    async def _ensure_target_collection(self) -> dict[str, object]:
        return await self.zotero_client.get_or_create_collection()

    async def _reconcile_existing_synced_record(self, db: Session, record: SyncRecordModel) -> ZoteroSyncResult:
        target_collection = {
            "name": self.zotero_client.target_collection_name,
            "key": None,
            "created": False,
        }
        if not self.zotero_client.is_configured():
            return self._build_sync_result(
                record=record,
                target_collection=target_collection,
                target_collection_status="not_configured",
                visibility_status="not_checked",
                visibility_message="本地已存在成功记录，但 Zotero 配置未完成，无法确认目标集合。",
            )

        try:
            target_collection = await self._ensure_target_collection()
        except Exception as exc:  # noqa: BLE001
            return self._build_sync_result(
                record=record,
                target_collection=target_collection,
                target_collection_status="error",
                visibility_status="not_checked",
                visibility_message=f"本地已存在成功记录，但集合准备失败：{exc}",
            )

        collection_key = str(target_collection["key"])
        if not record.zotero_item_key:
            return self._build_sync_result(
                record=record,
                target_collection=target_collection,
                target_collection_status="created" if bool(target_collection["created"]) else "ready",
                visibility_status="not_checked",
                visibility_message="本地已存在成功记录，但缺少 Zotero 条目 Key，无法远端确认集合归档。",
            )

        visibility = await self._verify_item_visibility(record.zotero_item_key, collection_key)
        if visibility["status"] == "missing_from_collection":
            visibility = await self._repair_item_collection_membership(record.zotero_item_key, collection_key)

        message = "已确认同步条目归档到目标集合。" if visibility["status"] == "verified" else record.message
        if message != record.message:
            record = self._upsert_record(
                db,
                record.paper_id,
                status="synced",
                message=message,
                zotero_item_key=record.zotero_item_key,
            )

        return self._build_sync_result(
            record=record,
            target_collection=target_collection,
            target_collection_status="created" if bool(target_collection["created"]) else "ready",
            visibility_status=str(visibility["status"]),
            visibility_message=str(visibility["message"]),
        )

    async def _verify_item_visibility(self, item_key: str, collection_key: str) -> dict[str, str]:
        try:
            visible = await self.zotero_client.is_item_in_collection(item_key, collection_key)
        except Exception as exc:  # noqa: BLE001
            return {
                "status": "unverified",
                "message": f"已提交同步，但读取可见性校验失败：{exc}",
            }
        if visible:
            return {
                "status": "verified",
                "message": "已确认条目出现在目标集合中。",
            }
        return {
            "status": "missing_from_collection",
            "message": "同步请求成功，但未在目标集合中读取到该条目。",
        }

    async def _repair_item_collection_membership(self, item_key: str, collection_key: str) -> dict[str, str]:
        try:
            await self.zotero_client.add_item_to_collection(item_key, collection_key)
        except Exception as exc:  # noqa: BLE001
            return {
                "status": "missing_from_collection",
                "message": f"已创建条目，但补偿归档到目标集合失败：{exc}",
            }

        repaired = await self._verify_item_visibility(item_key, collection_key)
        if repaired["status"] == "verified":
            return {
                "status": "verified",
                "message": "已通过补偿归档确认条目出现在目标集合中。",
            }
        return {
            "status": repaired["status"],
            "message": f"已尝试补偿归档，但仍未确认集合可见：{repaired['message']}",
        }

    def _extract_item_key(self, response: dict[str, object]) -> str | None:
        for field_name in ("successful", "success"):
            successful = response.get(field_name)
            if not isinstance(successful, dict):
                continue
            for value in successful.values():
                if isinstance(value, str):
                    return value
                if isinstance(value, dict):
                    key = value.get("key")
                    if isinstance(key, str):
                        return key
        return None

    def _build_sync_result(
        self,
        record: SyncRecordModel,
        target_collection: dict[str, object],
        target_collection_status: str,
        visibility_status: str,
        visibility_message: str,
    ) -> ZoteroSyncResult:
        settings = getattr(self.zotero_client, "settings", None)
        synced_at = record.synced_at.astimezone(UTC).isoformat().replace("+00:00", "Z")
        return ZoteroSyncResult(
            paper_id=record.paper_id,
            status=record.status,
            zotero_item_key=record.zotero_item_key,
            message=record.message,
            synced_at=synced_at,
            library_type=getattr(settings, "zotero_library_type", None),
            user_id=getattr(settings, "zotero_user_id", None),
            target_collection_name=str(target_collection.get("name", self.zotero_client.target_collection_name)),
            target_collection_key=target_collection.get("key") and str(target_collection["key"]),
            target_collection_status=target_collection_status,
            visibility_status=visibility_status,
            visibility_message=visibility_message,
        )
