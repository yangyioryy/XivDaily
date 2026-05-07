from __future__ import annotations

from types import SimpleNamespace

import httpx
import pytest

from app.ai.llm_gateway import LlmGateway


def build_gateway(
    monkeypatch: pytest.MonkeyPatch,
    api_key: str | None = "test-key",
    base_url: str = "https://example.test/v1",
) -> LlmGateway:
    settings = SimpleNamespace(
        llm_api_key=api_key,
        llm_model="gpt-5.4",
        llm_base_url=base_url,
        llm_request_timeout_seconds=3,
    )
    monkeypatch.setattr("app.ai.llm_gateway.get_settings", lambda: settings)
    return LlmGateway()


@pytest.mark.anyio("asyncio")
async def test_complete_degrades_without_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    gateway = build_gateway(monkeypatch, api_key=None)

    result = await gateway.complete("hello", task_name="translation")

    assert result.status == "degraded"
    assert "未配置" in (result.warning or "")


@pytest.mark.anyio("asyncio")
async def test_complete_returns_success_text(monkeypatch: pytest.MonkeyPatch) -> None:
    gateway = build_gateway(monkeypatch)

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict[str, object]:
            return {"choices": [{"message": {"content": "translated content"}}]}

    class FakeClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, url: str, json: dict[str, object], headers: dict[str, str]) -> FakeResponse:
            assert url == "https://example.test/v1/chat/completions"
            assert headers["Authorization"] == "Bearer test-key"
            assert json["model"] == "gpt-5.4"
            return FakeResponse()

    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: FakeClient())

    result = await gateway.complete("hello", task_name="translation")

    assert result.status == "success"
    assert result.text == "translated content"


@pytest.mark.anyio("asyncio")
async def test_complete_prefers_v1_path_for_bare_base_url(monkeypatch: pytest.MonkeyPatch) -> None:
    gateway = build_gateway(monkeypatch, base_url="https://yangyioryy.cc.cd")

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict[str, object]:
            return {"choices": [{"message": {"content": "ok"}}]}

    class FakeClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, url: str, json: dict[str, object], headers: dict[str, str]) -> FakeResponse:
            assert url == "https://yangyioryy.cc.cd/v1/chat/completions"
            return FakeResponse()

    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: FakeClient())

    result = await gateway.chat([{"role": "user", "content": "hello"}], task_name="paper_chat")

    assert result.status == "success"
    assert result.text == "ok"


@pytest.mark.anyio("asyncio")
async def test_complete_falls_back_to_legacy_path_when_v1_returns_404(monkeypatch: pytest.MonkeyPatch) -> None:
    gateway = build_gateway(monkeypatch, base_url="https://legacy.example.test")
    requested_urls: list[str] = []

    class FakeResponse:
        def __init__(self, url: str, status_code: int) -> None:
            self.request = httpx.Request("POST", url)
            self.status_code = status_code

        def raise_for_status(self) -> None:
            if self.status_code >= 400:
                response = httpx.Response(self.status_code, request=self.request)
                raise httpx.HTTPStatusError("not found", request=self.request, response=response)

        def json(self) -> dict[str, object]:
            return {"choices": [{"message": {"content": "legacy ok"}}]}

    class FakeClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, url: str, json: dict[str, object], headers: dict[str, str]) -> FakeResponse:
            requested_urls.append(url)
            if url.endswith("/v1/chat/completions"):
                return FakeResponse(url, 404)
            return FakeResponse(url, 200)

    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: FakeClient())

    result = await gateway.complete("hello", task_name="translation")

    assert result.status == "success"
    assert result.text == "legacy ok"
    assert requested_urls == [
        "https://legacy.example.test/v1/chat/completions",
        "https://legacy.example.test/chat/completions",
    ]


@pytest.mark.anyio("asyncio")
async def test_complete_degrades_after_retries(monkeypatch: pytest.MonkeyPatch) -> None:
    gateway = build_gateway(monkeypatch)
    attempts = {"count": 0}

    class FailingClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, url: str, json: dict[str, object], headers: dict[str, str]):
            attempts["count"] += 1
            raise httpx.ReadTimeout("timeout")

    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: FailingClient())

    result = await gateway.complete("hello", task_name="translation")

    assert attempts["count"] == 3
    assert result.status == "degraded"
    assert result.warning == "大模型请求超时，已使用本地降级结果。"


@pytest.mark.anyio("asyncio")
async def test_complete_maps_auth_failure_warning(monkeypatch: pytest.MonkeyPatch) -> None:
    gateway = build_gateway(monkeypatch)

    class UnauthorizedClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def post(self, url: str, json: dict[str, object], headers: dict[str, str]):
            request = httpx.Request("POST", url)
            response = httpx.Response(status_code=401, request=request, text="unauthorized")
            raise httpx.HTTPStatusError("unauthorized", request=request, response=response)

    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: UnauthorizedClient())

    result = await gateway.complete("hello", task_name="trend_summary")

    assert result.status == "degraded"
    assert result.warning == "大模型鉴权失败，请检查 API Key 或模型权限。"
