from pydantic import BaseModel, Field


class ZoteroConfigStatus(BaseModel):
    configured: bool = Field(description="是否已完成 Zotero 配置")
    user_id: str | None = Field(default=None, description="配置的用户 ID")
    library_type: str = Field(default="user", description="库类型")
    warning: str | None = Field(default=None, description="未配置或异常提示")


class BibtexExportRequest(BaseModel):
    paper_ids: list[str] = Field(description="待导出的论文 ID 列表")


class BibtexExportResponse(BaseModel):
    content: str = Field(description="BibTeX 文本")
    exported_count: int = Field(description="导出数量")

