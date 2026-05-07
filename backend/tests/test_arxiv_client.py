from __future__ import annotations

from types import SimpleNamespace

import httpx
import pytest

from app.clients.arxiv_client import ArxivClient


EMPTY_FEED = """<?xml version='1.0' encoding='UTF-8'?>
<feed xmlns="http://www.w3.org/2005/Atom"></feed>
"""


def build_client() -> ArxivClient:
    client = ArxivClient()
    client.settings = SimpleNamespace(arxiv_request_timeout_seconds=20, arxiv_base_url="https://example.test")
    return client


def build_search_client(monkeypatch: pytest.MonkeyPatch) -> ArxivClient:
    settings = SimpleNamespace(
        arxiv_base_url="https://export.arxiv.org/api/query",
        arxiv_request_timeout_seconds=3,
    )
    monkeypatch.setattr("app.clients.arxiv_client.get_settings", lambda: settings)
    client = ArxivClient()
    client._min_request_interval_seconds = 0
    ArxivClient._last_request_at = 0
    return client


def test_parse_entries_extracts_expected_fields() -> None:
    xml_text = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">
  <entry>
    <id>http://arxiv.org/abs/2401.00001v1</id>
    <updated>2026-04-29T10:00:00Z</updated>
    <published>2026-04-28T10:00:00Z</published>
    <title>  Test   Paper Title  </title>
    <summary>  First line
      second line  </summary>
    <author><name>Alice Example</name></author>
    <author><name>Bob Example</name></author>
    <link rel="alternate" href="https://arxiv.org/abs/2401.00001v1" />
    <link title="pdf" href="https://arxiv.org/pdf/2401.00001v1" />
    <category term="cs.CV" />
    <category term="cs.AI" />
    <arxiv:primary_category term="cs.CV" />
  </entry>
</feed>
"""
    client = build_client()

    entries = client._parse_entries(xml_text)

    assert len(entries) == 1
    entry = entries[0]
    assert entry["id"] == "2401.00001v1"
    assert entry["title"] == "Test Paper Title"
    assert entry["summary"] == "First line second line"
    assert entry["authors"] == ["Alice Example", "Bob Example"]
    assert entry["categories"] == ["cs.CV", "cs.AI"]
    assert entry["primary_category"] == "cs.CV"
    assert entry["source_url"] == "https://arxiv.org/abs/2401.00001v1"
    assert entry["pdf_url"] == "https://arxiv.org/pdf/2401.00001v1"


def test_parse_entries_falls_back_when_primary_category_missing() -> None:
    xml_text = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">
  <entry>
    <id>http://arxiv.org/abs/2401.00002v1</id>
    <updated>2026-04-29T10:00:00Z</updated>
    <published>2026-04-28T10:00:00Z</published>
    <title>Fallback Category</title>
    <summary>Summary</summary>
    <author><name>Alice Example</name></author>
    <link rel="alternate" href="https://arxiv.org/abs/2401.00002v1" />
    <category term="cs.CL" />
  </entry>
</feed>
"""
    client = build_client()

    entries = client._parse_entries(xml_text)

    assert entries[0]["primary_category"] == "cs.CL"


@pytest.mark.anyio("asyncio")
async def test_search_sets_descriptive_user_agent(monkeypatch: pytest.MonkeyPatch) -> None:
    client = build_search_client(monkeypatch)
    seen_headers: list[dict[str, str]] = []

    class FakeResponse:
        status_code = 200
        text = EMPTY_FEED

        def raise_for_status(self) -> None:
            return None

    class FakeClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url: str, params: dict[str, object], headers: dict[str, str]) -> FakeResponse:
            seen_headers.append(headers)
            return FakeResponse()

    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: FakeClient())

    result = await client.search("cs.CV", None, 10)

    assert result == []
    assert seen_headers[0]["User-Agent"].startswith("XivDaily/0.1.0")


@pytest.mark.anyio("asyncio")
async def test_search_retries_when_arxiv_returns_429(monkeypatch: pytest.MonkeyPatch) -> None:
    client = build_search_client(monkeypatch)
    requested_statuses = [429, 200]
    calls = 0

    async def fake_sleep(seconds: float) -> None:
        return None

    class FakeResponse:
        def __init__(self, status_code: int) -> None:
            self.status_code = status_code
            self.text = EMPTY_FEED
            self.request = httpx.Request("GET", "https://export.arxiv.org/api/query")

        def raise_for_status(self) -> None:
            if self.status_code >= 400:
                response = httpx.Response(self.status_code, request=self.request)
                raise httpx.HTTPStatusError("rate limited", request=self.request, response=response)

    class FakeClient:
        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url: str, params: dict[str, object], headers: dict[str, str]) -> FakeResponse:
            nonlocal calls
            calls += 1
            return FakeResponse(requested_statuses.pop(0))

    monkeypatch.setattr("app.clients.arxiv_client.asyncio.sleep", fake_sleep)
    monkeypatch.setattr(httpx, "AsyncClient", lambda timeout: FakeClient())

    result = await client.search("cs.CV", None, 10)

    assert result == []
    assert calls == 2
