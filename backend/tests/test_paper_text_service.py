import pytest

from app.services.paper_text_service import PaperTextService


def test_validate_arxiv_pdf_url_accepts_arxiv_pdf() -> None:
    service = PaperTextService()

    service._validate_arxiv_pdf_url("https://arxiv.org/pdf/2401.00001")


def test_validate_arxiv_pdf_url_rejects_non_arxiv_host() -> None:
    service = PaperTextService()

    with pytest.raises(ValueError):
        service._validate_arxiv_pdf_url("https://example.com/pdf/2401.00001")


def test_validate_arxiv_pdf_url_rejects_non_pdf_path() -> None:
    service = PaperTextService()

    with pytest.raises(ValueError):
        service._validate_arxiv_pdf_url("https://arxiv.org/abs/2401.00001")
