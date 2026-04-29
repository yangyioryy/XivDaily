from datetime import datetime

from pydantic import BaseModel, Field


class Paper(BaseModel):
    id: str = Field(description="论文唯一标识，默认使用 arXiv id")
    title: str = Field(description="论文标题")
    authors: list[str] = Field(description="作者列表")
    summary: str = Field(description="原始摘要")
    translated_summary: str | None = Field(default=None, description="翻译摘要")
    published_at: datetime = Field(description="首次发布时间")
    updated_at: datetime = Field(description="最近更新时间")
    categories: list[str] = Field(description="全部分类")
    primary_category: str = Field(description="主分类")
    source_url: str = Field(description="arXiv 页面链接")
    pdf_url: str = Field(description="PDF 链接")
    favorite_state: bool = Field(default=False, description="当前是否已收藏")
    zotero_sync_state: str = Field(default="not_synced", description="Zotero 三态同步状态")


class PaperQuery(BaseModel):
    keyword: str | None = Field(default=None, description="关键词")
    category: str | None = Field(default=None, description="分类")
    days: int = Field(ge=1, le=30, description="回溯天数")
    page: int = Field(ge=1, description="页码")
    page_size: int = Field(ge=1, le=50, description="每页数量")


class PaperListResponse(BaseModel):
    query: PaperQuery
    items: list[Paper]
    page: int
    page_size: int
    total: int
    has_more: bool
    status: str = Field(default="ok", description="列表状态：ok、stale、empty 或 unavailable")
    warning: str | None = Field(default=None, description="需要提示给前端的补充说明")
    empty_reason: str | None = Field(
        default=None,
        description="空列表原因：time_window_filtered、no_results，非空时留空",
    )
