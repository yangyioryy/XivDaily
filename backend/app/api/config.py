from fastapi import APIRouter, Depends

from app.schemas.config import (
    ConfigTestResult,
    IntegrationConfigRead,
    LlmConfigSaveRequest,
    ZoteroConfigSaveRequest,
)
from app.services.config_service import ConfigService

router = APIRouter(prefix="/config", tags=["config"])


def get_config_service() -> ConfigService:
    return ConfigService()


@router.get("/integrations", response_model=IntegrationConfigRead)
def read_integrations(service: ConfigService = Depends(get_config_service)) -> IntegrationConfigRead:
    return service.read_config()


@router.put("/zotero", response_model=IntegrationConfigRead)
def save_zotero_config(
    request: ZoteroConfigSaveRequest,
    service: ConfigService = Depends(get_config_service),
) -> IntegrationConfigRead:
    return service.save_zotero(request)


@router.post("/zotero/test", response_model=ConfigTestResult)
def test_zotero_config(service: ConfigService = Depends(get_config_service)) -> ConfigTestResult:
    return service.test_zotero_configured()


@router.put("/llm", response_model=IntegrationConfigRead)
def save_llm_config(
    request: LlmConfigSaveRequest,
    service: ConfigService = Depends(get_config_service),
) -> IntegrationConfigRead:
    return service.save_llm(request)


@router.post("/llm/test", response_model=ConfigTestResult)
def test_llm_config(service: ConfigService = Depends(get_config_service)) -> ConfigTestResult:
    return service.test_llm_configured()
