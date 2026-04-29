from pydantic import BaseModel, Field


class ZoteroConfigStatus(BaseModel):
    configured: bool = Field(description="是否已完成 Zotero 配置")
    user_id: str | None = Field(default=None, description="配置的用户 ID")
    library_type: str = Field(default="user", description="库类型")
    target_collection_name: str = Field(description="统一归档集合名称")
    target_collection_key: str | None = Field(default=None, description="统一归档集合 Key")
    target_collection_status: str = Field(description="统一归档集合状态：not_configured、ready、created 或 error")
    warning: str | None = Field(default=None, description="未配置或异常提示")


class BibtexExportRequest(BaseModel):
    paper_ids: list[str] = Field(description="待导出的论文 ID 列表")


class BibtexExportResponse(BaseModel):
    content: str = Field(description="BibTeX 文本")
    exported_count: int = Field(description="导出数量")


class ZoteroSyncResult(BaseModel):
    paper_id: str = Field(description="本次同步的论文 ID")
    status: str = Field(description="同步状态：synced 或 failed")
    zotero_item_key: str | None = Field(default=None, description="远端 Zotero 条目 Key")
    message: str | None = Field(default=None, description="同步结果摘要")
    synced_at: str = Field(description="本地记录更新时间")
    library_type: str | None = Field(default=None, description="目标 library 类型")
    user_id: str | None = Field(default=None, description="目标 Zotero user/group ID")
    target_collection_name: str = Field(description="目标集合名称")
    target_collection_key: str | None = Field(default=None, description="目标集合 Key")
    target_collection_status: str = Field(description="目标集合状态：ready、created、error 或 not_configured")
    visibility_status: str = Field(
        description="可见性状态：verified、missing_from_collection、unverified 或 not_checked",
    )
    visibility_message: str | None = Field(default=None, description="可见性校验说明")
