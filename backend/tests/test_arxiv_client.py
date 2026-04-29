from __future__ import annotations

from types import SimpleNamespace

from app.clients.arxiv_client import ArxivClient


def build_client() -> ArxivClient:
    client = ArxivClient()
    client.settings = SimpleNamespace(arxiv_request_timeout_seconds=20, arxiv_base_url="https://example.test")
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
