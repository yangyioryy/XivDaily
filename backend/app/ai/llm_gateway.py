from __future__ import annotations

import asyncio
import hashlib
import json
import logging
from dataclasses import dataclass
from time import monotonic
from typing import Literal

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class LlmResult:
    text: str
    status: str
    warning: str | None = None


@dataclass
class FailureCacheEntry:
    created_at: float
    result: LlmResult


ChatMessage = dict[str, Literal["system", "user", "assistant"] | str]


class EmptyLlmResponseError(RuntimeError):
    """模型服务返回成功状态，但没有可展示的正文。"""


class LlmGateway:
    """统一大模型网关，集中处理密钥、超时、重试和降级日志。"""

    _shared_failure_cache: dict[str, FailureCacheEntry] = {}
    _retryable_status_codes = {429, 502, 503, 504}
    _max_attempts = 3
    _failure_cache_ttl_seconds = 120.0

    def __init__(self) -> None:
        self.settings = get_settings()

    async def complete(self, prompt: str, task_name: str) -> LlmResult:
        return await self.chat([{"role": "user", "content": prompt}], task_name=task_name)

    async def chat(self, messages: list[ChatMessage], task_name: str) -> LlmResult:
        if not self.settings.llm_api_key:
            return LlmResult(text="", status="degraded", warning="未配置大模型 API Key，已使用本地降级结果。")

        payload = {
            "model": self.settings.llm_model,
            "messages": messages,
            "temperature": 0.2,
            "stream": False,
        }
        headers = {"Authorization": f"Bearer {self.settings.llm_api_key}"}
        started = monotonic()
        endpoints = self._chat_completion_urls()
        request_signature = self._build_request_signature(messages, task_name)
        cached_failure = self._get_cached_failure(request_signature)
        if cached_failure is not None:
            logger.info(
                "llm_call_short_circuited",
                extra={"task_name": task_name, "model": self.settings.llm_model, "endpoints": endpoints},
            )
            return cached_failure

        for attempt in range(1, self._max_attempts + 1):
            try:
                response = await self._post_chat_request(endpoints, payload, headers)
                content = self._extract_response_text(response.json())
                if not content.strip():
                    raise EmptyLlmResponseError("大模型响应内容为空")
                self.__class__._shared_failure_cache.pop(request_signature, None)
                logger.info(
                    "llm_call_success",
                    extra={"task_name": task_name, "attempt": attempt, "elapsed_ms": int((monotonic() - started) * 1000)},
                )
                return LlmResult(text=content, status="success")
            except Exception as exc:  # noqa: BLE001
                last_warning = self._map_warning(exc)
                retryable = self._should_retry(exc)
                # 失败响应可能带上游 URL 或账号信息，接口只返回通用提示，细节落在受控日志里
                # 方便定位是 base_url / key / model 哪个不对。
                status_code: int | None = None
                response_snippet = ""
                if isinstance(exc, httpx.HTTPStatusError):
                    status_code = exc.response.status_code
                    response_snippet = exc.response.text[:300].replace("\n", " ")
                logger.warning(
                    "llm_call_failed task=%s attempt=%s model=%s endpoints=%s "
                    "error_type=%s status_code=%s message=%s response=%s retryable=%s",
                    task_name,
                    attempt,
                    self.settings.llm_model,
                    endpoints,
                    type(exc).__name__,
                    status_code,
                    str(exc)[:300],
                    response_snippet,
                    retryable,
                )
                if not retryable or attempt >= self._max_attempts:
                    result = LlmResult(
                        text="",
                        status="degraded",
                        warning=last_warning or "大模型调用失败，已使用本地降级结果。",
                    )
                    if retryable:
                        # 短时间内复用同类失败结果，避免上游抖动时被重复请求放大。
                        self._remember_failure(request_signature, result)
                    else:
                        self.__class__._shared_failure_cache.pop(request_signature, None)
                    return result

                await asyncio.sleep(self._retry_delay_seconds(attempt, exc))

        return LlmResult(text="", status="degraded", warning="大模型调用失败，已使用本地降级结果。")

    def _chat_completion_urls(self) -> list[str]:
        base_url = self.settings.llm_base_url.rstrip("/")
        if base_url.endswith("/v1"):
            return [f"{base_url}/chat/completions"]
        return [f"{base_url}/v1/chat/completions", f"{base_url}/chat/completions"]

    async def _post_chat_request(
        self,
        endpoints: list[str],
        payload: dict[str, object],
        headers: dict[str, str],
    ) -> httpx.Response:
        async with httpx.AsyncClient(timeout=self.settings.llm_request_timeout_seconds) as client:
            response = None
            last_http_error: httpx.HTTPStatusError | None = None
            for endpoint in endpoints:
                try:
                    response = await client.post(endpoint, json=payload, headers=headers)
                    response.raise_for_status()
                    return response
                except httpx.HTTPStatusError as exc:
                    last_http_error = exc
                    # 兼容用户只填写裸域名的 OpenAI 风格服务；404 时继续尝试备用路径。
                    if exc.response.status_code == 404 and endpoint != endpoints[-1]:
                        continue
                    raise

        raise last_http_error or RuntimeError("大模型响应为空")

    def _extract_response_text(self, payload: object) -> str:
        if not isinstance(payload, dict):
            return ""

        choices = payload.get("choices")
        if not isinstance(choices, list) or not choices:
            return ""

        choice = choices[0]
        if not isinstance(choice, dict):
            return ""

        message = choice.get("message")
        if isinstance(message, dict):
            # 兼容部分 OpenAI 风格服务把 content 拆成数组片段的返回格式。
            for candidate in (message.get("content"), message.get("refusal")):
                content = self._stringify_visible_content(candidate)
                if content.strip():
                    return content

        return self._stringify_visible_content(choice.get("text"))

    def _stringify_visible_content(self, value: object) -> str:
        if isinstance(value, str):
            return value
        if isinstance(value, list):
            parts: list[str] = []
            for item in value:
                if isinstance(item, str):
                    parts.append(item)
                    continue
                if isinstance(item, dict):
                    text = item.get("text")
                    if isinstance(text, str):
                        parts.append(text)
            return "".join(parts)
        if isinstance(value, dict):
            text = value.get("text")
            return text if isinstance(text, str) else ""
        return ""

    def _build_request_signature(self, messages: list[ChatMessage], task_name: str) -> str:
        payload = {
            "task_name": task_name,
            "model": self.settings.llm_model,
            "base_url": self.settings.llm_base_url.rstrip("/"),
            "messages": messages,
        }
        serialized = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(serialized.encode("utf-8")).hexdigest()

    def _get_cached_failure(self, request_signature: str) -> LlmResult | None:
        cached = self.__class__._shared_failure_cache.get(request_signature)
        if cached is None:
            return None
        if monotonic() - cached.created_at >= self._failure_cache_ttl_seconds:
            self.__class__._shared_failure_cache.pop(request_signature, None)
            return None
        return cached.result

    def _remember_failure(self, request_signature: str, result: LlmResult) -> None:
        self.__class__._shared_failure_cache[request_signature] = FailureCacheEntry(
            created_at=monotonic(),
            result=result,
        )

    def _should_retry(self, exc: Exception) -> bool:
        if isinstance(exc, httpx.TimeoutException):
            return True
        if isinstance(exc, httpx.HTTPStatusError):
            return exc.response.status_code in self._retryable_status_codes
        if isinstance(exc, httpx.RequestError):
            return True
        return False

    def _retry_delay_seconds(self, attempt: int, exc: Exception) -> float:
        if isinstance(exc, httpx.HTTPStatusError):
            retry_after = exc.response.headers.get("Retry-After")
            if retry_after:
                try:
                    return max(float(retry_after), 1.0)
                except ValueError:
                    pass
        return min(2 ** (attempt - 1), 8.0)

    def _map_warning(self, exc: Exception) -> str:
        message = str(exc).lower()
        if isinstance(exc, EmptyLlmResponseError):
            return "大模型返回了空内容，已使用本地降级结果。"
        if isinstance(exc, httpx.TimeoutException) or "timeout" in message:
            return "大模型请求超时，已使用本地降级结果。"
        if isinstance(exc, httpx.HTTPStatusError):
            status_code = exc.response.status_code
            if status_code in {401, 403}:
                return "大模型鉴权失败，请检查 API Key 或模型权限。"
            response_text = exc.response.text.lower()
            if "context" in response_text or "token" in response_text:
                return "大模型上下文长度超限，已使用本地降级结果。"
        if "context" in message or "token" in message:
            return "大模型上下文长度超限，已使用本地降级结果。"
        if isinstance(exc, httpx.RequestError):
            return "大模型网络请求失败，已使用本地降级结果。"
        return "大模型调用失败，已使用本地降级结果。"
