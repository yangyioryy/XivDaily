from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """集中读取环境变量，避免业务代码直接接触敏感配置来源。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = Field(default="XivDaily Backend", validation_alias="APP_NAME")
    app_env: str = Field(default="development", validation_alias="APP_ENV")
    app_host: str = Field(default="127.0.0.1", validation_alias="APP_HOST")
    app_port: int = Field(default=8000, validation_alias="APP_PORT")
    app_log_level: str = Field(default="INFO", validation_alias="APP_LOG_LEVEL")
    database_url: str = Field(default="sqlite:///./data/xivdaily.db", validation_alias="DATABASE_URL")
    arxiv_base_url: str = Field(default="https://export.arxiv.org/api/query", validation_alias="ARXIV_BASE_URL")
    arxiv_request_timeout_seconds: int = Field(default=20, validation_alias="ARXIV_REQUEST_TIMEOUT_SECONDS")
    arxiv_cache_ttl_seconds: int = Field(default=900, validation_alias="ARXIV_CACHE_TTL_SECONDS")
    llm_base_url: str = Field(default="https://api.openai.com/v1", validation_alias="LLM_BASE_URL")
    llm_api_key: str | None = Field(default=None, validation_alias="LLM_API_KEY")
    llm_model: str = Field(default="gpt-5.4", validation_alias="LLM_MODEL")
    llm_request_timeout_seconds: int = Field(default=30, validation_alias="LLM_REQUEST_TIMEOUT_SECONDS")
    zotero_base_url: str = Field(default="https://api.zotero.org", validation_alias="ZOTERO_BASE_URL")
    zotero_user_id: str | None = Field(default=None, validation_alias="ZOTERO_USER_ID")
    zotero_library_type: str = Field(default="user", validation_alias="ZOTERO_LIBRARY_TYPE")
    zotero_api_key: str | None = Field(default=None, validation_alias="ZOTERO_API_KEY")

    @property
    def sqlite_path(self) -> Path | None:
        """仅在 SQLite URL 下返回本地文件路径，方便启动时创建目录。"""
        prefix = "sqlite:///"
        if not self.database_url.startswith(prefix):
            return None
        return Path(self.database_url.removeprefix(prefix))


@lru_cache
def get_settings() -> Settings:
    return Settings()
