import json
from types import SimpleNamespace

import httpx
import pytest

from app.clients import zotero_client as zotero_client_module
from app.clients.zotero_client import ZoteroClient


def build_client_with_transport(monkeypatch, handler):
    settings = SimpleNamespace(
        zotero_base_url="https://api.zotero.org",
        zotero_user_id="12345",
        zotero_library_type="user",
        zotero_api_key="secret",
        zotero_target_collection_name="XivDaily",
    )
    monkeypatch.setattr(zotero_client_module, "get_settings", lambda: settings)

    transport = httpx.MockTransport(handler)
    original_async_client = httpx.AsyncClient

    def async_client_factory(*args, **kwargs):
        kwargs["transport"] = transport
        return original_async_client(*args, **kwargs)

    monkeypatch.setattr(zotero_client_module.httpx, "AsyncClient", async_client_factory)
    return ZoteroClient()


@pytest.mark.anyio("asyncio")
async def test_find_collection_by_name_searches_all_collections_and_follows_next_link(monkeypatch) -> None:
    requested_urls: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requested_urls.append(str(request.url))
        assert request.url.path == "/users/12345/collections"
        if "start=100" not in str(request.url):
            return httpx.Response(
                200,
                json=[{"key": "OTHER", "data": {"key": "OTHER", "name": "Other"}}],
                headers={
                    "Link": '<https://api.zotero.org/users/12345/collections?start=100&limit=100>; rel="next"',
                },
            )
        return httpx.Response(
            200,
            json=[{"key": "NESTED1", "data": {"key": "NESTED1", "name": "XivDaily", "parentCollection": "PARENT1"}}],
        )

    client = build_client_with_transport(monkeypatch, handler)

    collection = await client.find_collection_by_name("XivDaily")

    assert collection == {"name": "XivDaily", "key": "NESTED1"}
    assert len(requested_urls) == 2
    assert "limit=100" in requested_urls[0]


@pytest.mark.anyio("asyncio")
async def test_add_item_to_collection_patches_missing_membership(monkeypatch) -> None:
    patch_payloads: list[dict[str, object]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "GET" and request.url.path == "/users/12345/items/ITEM1234":
            return httpx.Response(
                200,
                json={
                    "key": "ITEM1234",
                    "data": {
                        "key": "ITEM1234",
                        "version": 7,
                        "collections": ["OLD1"],
                    },
                },
            )
        if request.method == "PATCH" and request.url.path == "/users/12345/items/ITEM1234":
            patch_payloads.append(json.loads(request.content.decode("utf-8")))
            assert request.headers["If-Unmodified-Since-Version"] == "7"
            return httpx.Response(204)
        raise AssertionError(f"unexpected request: {request.method} {request.url}")

    client = build_client_with_transport(monkeypatch, handler)

    await client.add_item_to_collection("ITEM1234", "COLL1234")

    assert patch_payloads == [{"collections": ["OLD1", "COLL1234"]}]
