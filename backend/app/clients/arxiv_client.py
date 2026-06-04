from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from time import monotonic
import xml.etree.ElementTree as ET

import httpx

from app.core.config import get_settings

ATOM_NS = {"atom": "http://www.w3.org/2005/Atom", "arxiv": "http://arxiv.org/schemas/atom"}
RETRYABLE_STATUS_CODES = {429, 502, 503, 504}

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ArxivSearchResult:
    items: list[dict[str, object]]
    status: str = "ok"
    warning: str | None = None


class ArxivClient:
    """arXiv Atom API client. It fetches metadata and parses XML only."""

    _rate_limit_lock = asyncio.Lock()
    _last_request_at = 0.0
    _min_request_interval_seconds = 3.2

    def __init__(self) -> None:
        self.settings = get_settings()
        self._min_request_interval_seconds = getattr(
            self.settings,
            "arxiv_min_request_interval_seconds",
            self.__class__._min_request_interval_seconds,
        )

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
        result = await self.search_with_status(category, keyword, max_results)
        return result.items

    async def search_with_status(
        self,
        category: str | None,
        keyword: str | None,
        max_results: int,
    ) -> ArxivSearchResult:
        query_parts: list[str] = []
        if category:
            query_parts.append(f"cat:{category}")
        if keyword:
            query_parts.append(f"all:{keyword}")
        search_query = " AND ".join(query_parts) if query_parts else "cat:cs.CV"

        params = {
            "search_query": search_query,
            "start": 0,
            "max_results": max_results,
            "sortBy": "submittedDate",
            "sortOrder": "descending",
        }
        headers = {"User-Agent": "XivDaily/0.1.0 (https://beginnerforever.eu.cc)"}
        async with httpx.AsyncClient(timeout=self.settings.arxiv_request_timeout_seconds) as client:
            for attempt in range(3):
                await self._respect_rate_limit()
                try:
                    response = await client.get(self.settings.arxiv_base_url, params=params, headers=headers)
                except (httpx.TimeoutException, httpx.RequestError) as exc:
                    if attempt >= 2:
                        logger.warning(
                            "arXiv request failed after retries. category=%s error=%s",
                            category,
                            exc,
                        )
                        return ArxivSearchResult(
                            items=[],
                            status="unavailable",
                            warning="arXiv 暂时无法连接，已返回空结果。请稍后重试。",
                        )
                    await asyncio.sleep(self._retry_delay_seconds(attempt))
                    continue

                if response.status_code in RETRYABLE_STATUS_CODES:
                    if attempt >= 2:
                        logger.warning(
                            "arXiv returned retryable status after retries. category=%s status=%s",
                            category,
                            response.status_code,
                        )
                        if response.status_code == 429:
                            return ArxivSearchResult(
                                items=[],
                                status="rate_limited",
                                warning="arXiv 当前限流，已重试但仍失败。可以稍后重试，或切换分类后再搜索。",
                            )
                        return ArxivSearchResult(
                            items=[],
                            status="unavailable",
                            warning="arXiv 暂时不可用，已重试但仍失败。请稍后重试。",
                        )
                    await asyncio.sleep(self._retry_delay_seconds(attempt, response))
                    continue

                try:
                    response.raise_for_status()
                except httpx.HTTPStatusError as exc:
                    logger.warning("arXiv returned non-retryable status. category=%s error=%s", category, exc)
                    return ArxivSearchResult(
                        items=[],
                        status="unavailable",
                        warning="arXiv 暂时无法完成搜索请求，请稍后重试或调整搜索条件。",
                    )
                try:
                    return ArxivSearchResult(items=self._parse_entries(response.text))
                except ET.ParseError as exc:
                    logger.warning("arXiv XML parse failed. category=%s error=%s", category, exc)
                    return ArxivSearchResult(
                        items=[],
                        status="unavailable",
                        warning="arXiv 返回内容暂时无法解析，请稍后重试。",
                    )
        return ArxivSearchResult(
            items=[],
            status="unavailable",
            warning="arXiv 搜索暂时不可用，请稍后重试。",
        )

    def _retry_delay_seconds(self, attempt: int, response: httpx.Response | None = None) -> float:
        if response is not None:
            retry_after = getattr(response, "headers", {}).get("Retry-After")
            if retry_after:
                try:
                    return max(float(retry_after), self._min_request_interval_seconds)
                except ValueError:
                    pass
        return max(4.0 * (attempt + 1), self._min_request_interval_seconds)

    async def _respect_rate_limit(self) -> None:
        async with self._rate_limit_lock:
            elapsed = monotonic() - self.__class__._last_request_at
            wait_seconds = self._min_request_interval_seconds - elapsed
            if wait_seconds > 0:
                await asyncio.sleep(wait_seconds)
            self.__class__._last_request_at = monotonic()

    def _parse_entries(self, xml_text: str) -> list[dict[str, object]]:
        root = ET.fromstring(xml_text)
        entries: list[dict[str, object]] = []
        for entry in root.findall("atom:entry", ATOM_NS):
            links = entry.findall("atom:link", ATOM_NS)
            source_url = self._find_link(links, "alternate")
            pdf_url = self._find_pdf_link(links)
            categories = [
                category.attrib.get("term", "")
                for category in entry.findall("atom:category", ATOM_NS)
                if category.attrib.get("term")
            ]
            primary_category = entry.find("arxiv:primary_category", ATOM_NS)
            primary_category_value = (
                primary_category.attrib.get("term", categories[0] if categories else "")
                if primary_category is not None
                else (categories[0] if categories else "")
            )
            entries.append(
                {
                    "id": self._text(entry, "atom:id").rsplit("/", 1)[-1],
                    "title": " ".join(self._text(entry, "atom:title").split()),
                    "authors": [
                        self._text(author, "atom:name")
                        for author in entry.findall("atom:author", ATOM_NS)
                    ],
                    "summary": " ".join(self._text(entry, "atom:summary").split()),
                    "published_at": self._text(entry, "atom:published"),
                    "updated_at": self._text(entry, "atom:updated"),
                    "categories": categories,
                    "primary_category": primary_category_value,
                    "source_url": source_url,
                    "pdf_url": pdf_url,
                }
            )
        return entries

    def _text(self, element: ET.Element, path: str) -> str:
        node = element.find(path, ATOM_NS)
        return node.text.strip() if node is not None and node.text else ""

    def _find_link(self, links: list[ET.Element], rel: str) -> str:
        for link in links:
            if link.attrib.get("rel") == rel:
                return link.attrib.get("href", "")
        return ""

    def _find_pdf_link(self, links: list[ET.Element]) -> str:
        for link in links:
            if link.attrib.get("title") == "pdf" or link.attrib.get("type") == "application/pdf":
                return link.attrib.get("href", "")
        return ""
