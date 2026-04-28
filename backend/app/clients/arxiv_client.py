from __future__ import annotations

import xml.etree.ElementTree as ET

import httpx

from app.core.config import get_settings

ATOM_NS = {"atom": "http://www.w3.org/2005/Atom", "arxiv": "http://arxiv.org/schemas/atom"}


class ArxivClient:
    """arXiv Atom API 客户端，只负责请求和 XML 解析，不做业务过滤。"""

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
        async with httpx.AsyncClient(timeout=self.settings.arxiv_request_timeout_seconds) as client:
            response = await client.get(self.settings.arxiv_base_url, params=params)
            response.raise_for_status()
        return self._parse_entries(response.text)

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
                    "primary_category": entry.find("arxiv:primary_category", ATOM_NS).attrib.get("term", categories[0] if categories else ""),
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

