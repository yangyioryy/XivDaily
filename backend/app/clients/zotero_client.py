from __future__ import annotations

import httpx

from app.core.config import get_settings


class ZoteroClient:
    """Zotero Web API 客户端，负责远端写入请求。"""

    def __init__(self) -> None:
        self.settings = get_settings()

    def is_configured(self) -> bool:
        return bool(self.settings.zotero_user_id and self.settings.zotero_api_key)

    async def create_item(self, item_payload: dict[str, object]) -> dict[str, object]:
        headers = {
            "Zotero-API-Key": self.settings.zotero_api_key or "",
            "Zotero-Write-Token": item_payload["itemKey"],
            "Content-Type": "application/json",
        }
        url = f"{self.settings.zotero_base_url}/users/{self.settings.zotero_user_id}/items"
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(url, json=[item_payload["data"]], headers=headers)
            response.raise_for_status()
        return response.json()

