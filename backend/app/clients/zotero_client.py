from __future__ import annotations

import secrets

import httpx

from app.core.config import get_settings

DEFAULT_ZOTERO_COLLECTION_NAME = "XivDaily"


class ZoteroClient:
    """Zotero Web API 客户端，负责集合与条目的远端读写。"""

    def __init__(self) -> None:
        self.settings = get_settings()

    def is_configured(self) -> bool:
        return bool(self.settings.zotero_user_id and self.settings.zotero_api_key)

    @property
    def target_collection_name(self) -> str:
        return DEFAULT_ZOTERO_COLLECTION_NAME

    async def create_item(self, item_payload: dict[str, object]) -> dict[str, object]:
        headers = self._write_headers(str(item_payload["itemKey"]))
        url = f"{self.settings.zotero_base_url}/{self._library_prefix()}/items"
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(url, json=[item_payload["data"]], headers=headers)
            response.raise_for_status()
        return response.json()

    async def get_or_create_collection(self, collection_name: str | None = None) -> dict[str, object]:
        target_name = collection_name or self.target_collection_name
        existing = await self.find_collection_by_name(target_name)
        if existing is not None:
            return {"name": existing["name"], "key": existing["key"], "created": False}

        response = await self.create_collection(target_name)
        created_key = self._extract_write_key(response)
        if created_key is None:
            # Zotero 写接口在不同场景下返回格式略有差异，兜底再查一次集合保证结果可用。
            created = await self.find_collection_by_name(target_name)
            if created is None:
                raise ValueError("Zotero 归档集合创建成功，但未能解析集合 Key。")
            created_key = created["key"]
        return {"name": target_name, "key": created_key, "created": True}

    async def find_collection_by_name(self, collection_name: str) -> dict[str, str] | None:
        url = f"{self.settings.zotero_base_url}/{self._library_prefix()}/collections/top"
        headers = self._default_headers()
        params: dict[str, object] | None = {"limit": 100}
        async with httpx.AsyncClient(timeout=20) as client:
            next_url: str | None = url
            while next_url is not None:
                response = await client.get(next_url, headers=headers, params=params)
                response.raise_for_status()
                for raw_collection in response.json():
                    normalized = self._normalize_collection(raw_collection)
                    if normalized is not None and normalized["name"] == collection_name:
                        return normalized
                next_url = self._extract_next_link(response)
                params = None
        return None

    async def create_collection(self, collection_name: str) -> dict[str, object]:
        headers = self._write_headers(secrets.token_hex(16))
        url = f"{self.settings.zotero_base_url}/{self._library_prefix()}/collections"
        payload = {"name": collection_name}
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
        return response.json()

    def _library_prefix(self) -> str:
        resource = "groups" if self.settings.zotero_library_type == "group" else "users"
        return f"{resource}/{self.settings.zotero_user_id}"

    def _default_headers(self) -> dict[str, str]:
        return {
            "Zotero-API-Key": self.settings.zotero_api_key or "",
            "Zotero-API-Version": "3",
        }

    def _write_headers(self, write_token: str) -> dict[str, str]:
        headers = self._default_headers()
        headers["Zotero-Write-Token"] = write_token
        headers["Content-Type"] = "application/json"
        return headers

    def _normalize_collection(self, raw_collection: object) -> dict[str, str] | None:
        if not isinstance(raw_collection, dict):
            return None
        data = raw_collection.get("data")
        if not isinstance(data, dict):
            return None
        name = data.get("name")
        key = raw_collection.get("key") or data.get("key")
        if isinstance(name, str) and isinstance(key, str):
            return {"name": name, "key": key}
        return None

    def _extract_write_key(self, response: dict[str, object]) -> str | None:
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

    def _extract_next_link(self, response: httpx.Response) -> str | None:
        link_header = response.headers.get("Link")
        if not link_header:
            return None
        for part in link_header.split(","):
            normalized = part.strip()
            if 'rel="next"' not in normalized and "rel=next" not in normalized:
                continue
            if "<" not in normalized or ">" not in normalized:
                continue
            return normalized.split("<", 1)[1].split(">", 1)[0]
        return None
