def build_trend_prompt(days: int, category: str | None, paper_snippets: list[str]) -> str:
    focus = category or "全部关注领域"
    joined = "\n".join(paper_snippets[:12])
    return (
        f"你是科研论文趋势分析助手。请基于最近 {days} 天、领域 {focus} 的论文，"
        "总结最多 3 个研究趋势，并严格输出 JSON。\n"
        "JSON 格式为："
        '{"intro":"一句总览","items":[{"rank":1,"trend_title":"⚙️ 方向标题","summary":"一句简短说明","representative_paper_ids":["2401.00001"]}]}\n'
        "要求：1. trend_title 必须带 emoji；2. summary 用简体中文；3. representative_paper_ids 只能引用给定论文编号；4. 不要输出 JSON 之外的内容。\n"
        f"论文列表：\n{joined}"
    )


def build_translation_prompt(source_summary: str, target_language: str) -> str:
    return (
        f"请将以下 arXiv 论文摘要翻译为 {target_language}。"
        "要求术语准确、表达自然，不添加原文没有的信息。\n"
        f"摘要：\n{source_summary}"
    )
