from __future__ import annotations

import logging
from dataclasses import dataclass
from time import monotonic

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class LlmResult:
    text: str
    status: str
    warning: str | None = None


class LlmGateway:
    """统一大模型网关，集中处理密钥、超时、重试和降级日志。"""

    def __init__(self) -> None:
        self.settings = get_settings()

    async def complete(self, prompt: str, task_name: str) -> LlmResult:
        if not self.settings.llm_api_key:
            return LlmResult(text="", status="degraded", warning="未配置大模型 API Key，已使用本地降级结果。")

        payload = {
            "model": self.settings.llm_model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
        }
        headers = {"Authorization": f"Bearer {self.settings.llm_api_key}"}
        started = monotonic()

        for attempt in range(1, 4):
            try:
                async with httpx.AsyncClient(timeout=self.settings.llm_request_timeout_seconds) as client:
                    response = await client.post(f"{self.settings.llm_base_url}/chat/completions", json=payload, headers=headers)
                    response.raise_for_status()
                content = response.json()["choices"][0]["message"]["content"]
                logger.info(
                    "llm_call_success",
                    extra={"task_name": task_name, "attempt": attempt, "elapsed_ms": int((monotonic() - started) * 1000)},
                )
                return LlmResult(text=content, status="success")
            except Exception as exc:  # noqa: BLE001
                # 失败响应可能带上游 URL 或账号信息，接口只返回通用提示，细节留在受控日志。
                logger.warning(
                    "llm_call_failed",
                    extra={"task_name": task_name, "attempt": attempt, "error_type": type(exc).__name__},
                )

        return LlmResult(text="", status="degraded", warning="大模型调用失败，已使用本地降级结果。")
