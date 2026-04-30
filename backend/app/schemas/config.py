from pydantic import BaseModel, Field


class SecretFieldState(BaseModel):
    configured: bool = Field(description="敏感字段是否已设置")
    masked: str | None = Field(default=None, description="脱敏展示值")


class ZoteroConfigRead(BaseModel):
    user_id: str | None = None
    library_type: str = "user"
    api_key: SecretFieldState
    target_collection_name: str = "XivDaily"


class LlmConfigRead(BaseModel):
    base_url: str
    api_key: SecretFieldState
    model: str


class IntegrationConfigRead(BaseModel):
    zotero: ZoteroConfigRead
    llm: LlmConfigRead


class ZoteroConfigSaveRequest(BaseModel):
    user_id: str | None = None
    library_type: str = "user"
    api_key: str | None = None
    target_collection_name: str = "XivDaily"


class LlmConfigSaveRequest(BaseModel):
    base_url: str = "https://api.openai.com/v1"
    api_key: str | None = None
    model: str = "gpt-5.4"


class ConfigTestResult(BaseModel):
    ok: bool
    status: str
    message: str
