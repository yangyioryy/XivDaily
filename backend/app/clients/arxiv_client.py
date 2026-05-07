from __future__ import annotations

import asyncio
from time import monotonic
import xml.etree.ElementTree as ET

import httpx

from app.core.config import get_settings

ATOM_NS = {"atom": "http://www.w3.org/2005/Atom", "arxiv": "http://arxiv.org/schemas/atom"}


class ArxivClient:
    """arXiv Atom API 客户端，只负责请求和 XML 解析，不做业务过滤。"""

    _rate_limit_lock = asyncio.Lock()
    _last_request_at = 0.0
    _min_request_interval_seconds = 3.2

    def __init__(self) -> None:
        self.settings = get_settings()

    async def search(self, category: str | None, keyword: str | None, max_results: int) -> list[dict[str, object]]:
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
                response = await client.get(self.settings.arxiv_base_url, params=params, headers=headers)
                if response.status_code == 429 and attempt < 2:
                    # arXiv 明确按请求频率限流；退避后重试，避免服务刚重启或多筛选并发时直接空列表。
                    await asyncio.sleep(4 * (attempt + 1))
                    continue
                response.raise_for_status()
                return self._parse_entries(response.text)
        return []

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
                    # 某些返回可能缺主分类标签，首版回退到分类列表首项避免解析直接失败。
                    "primary_category": primary_category.attrib.get("term", categories[0] if categories else "") if primary_category is not None else (categories[0] if categories else ""),
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
