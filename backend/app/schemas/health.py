from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """健康检查响应。"""

    status: str = Field(description="服务状态")
    environment: str = Field(description="运行环境")
    version: str = Field(description="服务版本")

