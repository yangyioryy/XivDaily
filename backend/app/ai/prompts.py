def build_trend_prompt(days: int, category: str | None, paper_snippets: list[str]) -> str:
    focus = category or "全部关注领域"
    joined = "\n".join(paper_snippets[:12])
    return (
        f"你是科研论文趋势分析助手。请基于最近 {days} 天、领域 {focus} 的论文，"
        "总结最多 3 个研究趋势，每个趋势给出标题、简短说明和代表论文编号。\n"
        "请使用简体中文，避免夸大论文贡献。\n"
        f"论文列表：\n{joined}"
    )


def build_translation_prompt(source_summary: str, target_language: str) -> str:
    return (
        f"请将以下 arXiv 论文摘要翻译为 {target_language}。"
        "要求术语准确、表达自然，不添加原文没有的信息。\n"
        f"摘要：\n{source_summary}"
    )

