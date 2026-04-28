from datetime import datetime

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

