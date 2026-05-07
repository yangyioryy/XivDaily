from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from urllib.parse import urlsplit

import httpx

from app.core.config import get_settings
from app.schemas.ai import PaperChatPaper


@dataclass
class PaperTextResult:
    paper_id: str
    title: str
    text: str
    status: str
    warning: str | None = None


class PaperTextService:
    """负责从受信任的 arXiv PDF 中提取论文文本，避免 AI 编排层直接处理网络文件。"""

    def __init__(self) -> None:
        self.settings = get_settings()

    async def extract_text(self, paper: PaperChatPaper) -> PaperTextResult:
        try:
            self._validate_arxiv_pdf_url(paper.pdf_url)
            pdf_bytes = await self._download_pdf(paper.pdf_url)
            text = self._extract_pdf_text(pdf_bytes).strip()
        except Exception as exc:  # noqa: BLE001
            fallback = paper.summary.strip()
            if fallback:
                return PaperTextResult(
                    paper_id=paper.paper_id,
                    title=paper.title,
                    text=fallback,
                    status="summary_fallback",
                    warning=f"全文读取失败，已降级为摘要：{exc}",
                )
            return PaperTextResult(
                paper_id=paper.paper_id,
                title=paper.title,
                text="",
                status="failed",
                warning=f"全文读取失败：{exc}",
            )

        if not text:
            return PaperTextResult(
                paper_id=paper.paper_id,
                title=paper.title,
                text=paper.summary.strip(),
                status="summary_fallback",
                warning="PDF 未提取到有效文本，已降级为摘要。",
            )

        return PaperTextResult(paper_id=paper.paper_id, title=paper.title, text=text, status="full_text")

    def _validate_arxiv_pdf_url(self, pdf_url: str) -> None:
        parsed = urlsplit(pdf_url)
        host = (parsed.hostname or "").lower()
        # 只允许 arXiv PDF 域名和 /pdf/ 路径，阻断 SSRF 与任意文件下载。
        if parsed.scheme != "https" or host not in {"arxiv.org", "www.arxiv.org"} or not parsed.path.startswith("/pdf/"):
            raise ValueError("仅支持 https://arxiv.org/pdf/... 格式的 PDF URL")

    async def _download_pdf(self, pdf_url: str) -> bytes:
        chunks: list[bytes] = []
        total = 0
        async with httpx.AsyncClient(timeout=self.settings.paper_pdf_timeout_seconds, follow_redirects=True) as client:
            async with client.stream("GET", pdf_url) as response:
                response.raise_for_status()
                content_length = response.headers.get("content-length")
                if content_length and int(content_length) > self.settings.paper_pdf_max_bytes:
                    raise ValueError("PDF 文件超过大小限制")
                async for chunk in response.aiter_bytes():
                    total += len(chunk)
                    if total > self.settings.paper_pdf_max_bytes:
                        raise ValueError("PDF 文件超过大小限制")
                    chunks.append(chunk)
        data = b"".join(chunks)
        if not data.startswith(b"%PDF"):
            raise ValueError("下载结果不是有效 PDF")
        return data

    def _extract_pdf_text(self, pdf_bytes: bytes) -> str:
        from pypdf import PdfReader

        reader = PdfReader(BytesIO(pdf_bytes))
        page_texts = [(page.extract_text() or "") for page in reader.pages]
        return "\n".join(" ".join(page_text.split()) for page_text in page_texts if page_text.strip())
