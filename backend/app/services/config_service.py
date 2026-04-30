from __future__ import annotations

import json
from typing import Any

from app.core.config import Settings, get_settings
from app.schemas.config import (
    ConfigTestResult,
    IntegrationConfigRead,
    LlmConfigRead,
    LlmConfigSaveRequest,
    SecretFieldState,
    ZoteroConfigRead,
    ZoteroConfigSaveRequest,
)


class ConfigService:
    """管理用户可写配置，所有敏感字段只以脱敏状态返回。"""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def read_config(self) -> IntegrationConfigRead:
        return IntegrationConfigRead(
            zotero=ZoteroConfigRead(
                user_id=self.settings.zotero_user_id,
                library_type=self.settings.zotero_library_type,
                api_key=self._secret_state(self.settings.zotero_api_key),
                target_collection_name=self.settings.zotero_target_collection_name,
            ),
            llm=LlmConfigRead(
                base_url=self.settings.llm_base_url,
                api_key=self._secret_state(self.settings.llm_api_key),
                model=self.settings.llm_model,
            ),
        )

    def save_zotero(self, request: ZoteroConfigSaveRequest) -> IntegrationConfigRead:
        user_id = request.user_id.strip() if request.user_id else None
        library_type = request.library_type.strip() or "user"
        target_collection_name = request.target_collection_name.strip() or "XivDaily"
        payload = self._load_payload()
        current_api_key = payload.get("zotero", {}).get("api_key") or self.settings.zotero_api_key
        api_key = request.api_key.strip() if request.api_key and request.api_key.strip() else current_api_key
        payload["zotero"] = {
            "user_id": user_id,
            "library_type": library_type,
            "api_key": api_key,
            "target_collection_name": target_collection_name,
        }
        self._write_payload(payload)
        self._apply_zotero(user_id, library_type, api_key, target_collection_name)
        return self.read_config()

    def save_llm(self, request: LlmConfigSaveRequest) -> IntegrationConfigRead:
        base_url = request.base_url.strip().rstrip("/") or "https://api.openai.com/v1"
        model = request.model.strip() or "gpt-5.4"
        payload = self._load_payload()
        current_api_key = payload.get("llm", {}).get("api_key") or self.settings.llm_api_key
        api_key = request.api_key.strip() if request.api_key and request.api_key.strip() else current_api_key
        payload["llm"] = {
            "base_url": base_url,
            "api_key": api_key,
            "model": model,
        }
        self._write_payload(payload)
        self._apply_llm(base_url, api_key, model)
        return self.read_config()

    def test_zotero_configured(self) -> ConfigTestResult:
        ok = bool(self.settings.zotero_user_id and self.settings.zotero_api_key)
        return ConfigTestResult(
            ok=ok,
            status="ready" if ok else "not_configured",
            message="Zotero 配置字段已填写，可以发起连接测试。" if ok else "请先填写 Zotero User ID 和 API Key。",
        )

    def test_llm_configured(self) -> ConfigTestResult:
        ok = bool(self.settings.llm_base_url and self.settings.llm_api_key and self.settings.llm_model)
        return ConfigTestResult(
            ok=ok,
            status="ready" if ok else "not_configured",
            message="大模型配置字段已填写，可以发起摘要与翻译请求。" if ok else "请先填写 Base URL、API Key 和模型名。",
        )

    def _load_payload(self) -> dict[str, Any]:
        path = self.settings.runtime_config_path
        if not path.exists():
            return {}
        return json.loads(path.read_text(encoding="utf-8"))

    def _write_payload(self, payload: dict[str, Any]) -> None:
        path = self.settings.runtime_config_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    def _apply_zotero(
        self,
        user_id: str | None,
        library_type: str,
        api_key: str | None,
        target_collection_name: str,
    ) -> None:
        self.settings.zotero_user_id = user_id
        self.settings.zotero_library_type = library_type
        self.settings.zotero_api_key = api_key
        self.settings.zotero_target_collection_name = target_collection_name

    def _apply_llm(self, base_url: str, api_key: str | None, model: str) -> None:
        self.settings.llm_base_url = base_url
        self.settings.llm_api_key = api_key
        self.settings.llm_model = model

    def _secret_state(self, value: str | None) -> SecretFieldState:
        if not value:
            return SecretFieldState(configured=False)
        suffix = value[-4:] if len(value) >= 4 else value
        return SecretFieldState(configured=True, masked=f"***{suffix}")
