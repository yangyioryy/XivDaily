from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class TrendSummaryItem(BaseModel):
    rank: int = Field(description="趋势排序")
    trend_title: str = Field(description="趋势标题")
    summary: str = Field(description="趋势说明")
    representative_paper_ids: list[str] = Field(description="代表论文 ID")


class TrendSummary(BaseModel):
    category: str | None = Field(default=None, description="当前分类")
    days: int = Field(description="时间窗口")
    generated_at: datetime = Field(description="生成时间")
    intro: str = Field(description="摘要开场文案")
    items: list[TrendSummaryItem] = Field(description="最多三条趋势")
    dismissible: bool = Field(default=True, description="是否允许关闭")
    status: str = Field(default="success", description="success 或 degraded")
    warning: str | None = Field(default=None, description="降级原因")


class TranslationRequest(BaseModel):
    paper_id: str = Field(description="论文 ID")
    source_summary: str = Field(description="原始摘要")
    target_language: str = Field(default="zh-CN", description="目标语言")


class TranslationTask(BaseModel):
    paper_id: str = Field(description="论文 ID")
    status: str = Field(description="success、degraded 或 failed")
    translated_summary: str = Field(description="翻译结果或降级文案")
    requested_at: datetime = Field(description="请求时间")
    warning: str | None = Field(default=None, description="降级或失败原因")


class PaperChatPaper(BaseModel):
    paper_id: str = Field(description="客户端收藏论文 ID")
    title: str = Field(description="论文标题")
    summary: str = Field(default="", description="论文摘要，全文不可用时作为降级上下文")
    pdf_url: str = Field(description="arXiv PDF URL")
    source_url: str | None = Field(default=None, description="arXiv abs/source URL")


class PaperChatMessage(BaseModel):
    role: Literal["user", "assistant"] = Field(description="对话角色")
    content: str = Field(min_length=1, description="消息内容")


class PaperChatRequest(BaseModel):
    papers: list[PaperChatPaper] = Field(min_length=1, max_length=3, description="本次对话选中的收藏论文")
    messages: list[PaperChatMessage] = Field(min_length=1, max_length=20, description="对话历史，最后一条应为用户问题")


class PaperChatUsedPaper(BaseModel):
    paper_id: str = Field(description="论文 ID")
    title: str = Field(description="论文标题")
    status: Literal["full_text", "summary_fallback", "failed"] = Field(description="本次使用的上下文来源")
    context_chars: int = Field(default=0, description="进入模型上下文的字符数")
    warning: str | None = Field(default=None, description="单篇论文读取警告")


class PaperChatResponse(BaseModel):
    answer: str = Field(description="AI 回答或降级回答")
    status: Literal["success", "degraded"] = Field(description="整体状态")
    created_at: datetime = Field(description="回答生成时间")
    used_papers: list[PaperChatUsedPaper] = Field(description="本次对话实际使用的论文上下文")
    warning: str | None = Field(default=None, description="整体降级原因")
