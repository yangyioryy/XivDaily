def build_trend_prompt(days: int, category: str | None, paper_snippets: list[str]) -> str:
    focus = category or "全部关注领域"
    joined = "\n".join(paper_snippets[:10])
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


def build_paper_chat_messages(paper_contexts: list[str], conversation: list[dict[str, str]]) -> list[dict[str, str]]:
    joined_context = "\n\n---\n\n".join(paper_contexts)
    normalized_conversation = "\n".join(
        f"{message['role']}: {message['content']}" for message in conversation if message.get("content")
    )
    return [
        {
            "role": "system",
            "content": (
                "你是严谨的论文阅读助手。必须优先依据用户选择论文的全文内容回答。"
                "每篇论文会提供 arXiv 页面和 PDF 链接；如果当前模型具备联网或检索能力，"
                "可以用这些链接补充查看原文。不确定时直接说明证据不足；不要编造论文中没有的信息。"
                "回答时使用简洁的 Markdown 结构（要点用列表、关键名词加粗、代码用代码块），"
                "避免冗长段落，可适度使用 emoji 提升可读性。"
            ),
        },
        {
            "role": "user",
            "content": (
                "以下是论文链接、已截断到安全上下文长度的本地材料和对话历史。\n\n"
                f"论文材料：\n{joined_context}\n\n"
                f"对话历史：\n{normalized_conversation}\n\n"
                "请用简体中文回答最后一个用户问题，并尽量点明依据来自哪篇论文；"
                "若本地材料不足且无法访问链接，请明确说明限制。"
            ),
        },
    ]
