from fastapi import APIRouter, Depends, Query

from app.schemas.ai import TranslationRequest, TranslationTask, TrendSummary
from app.services.ai_service import AiService

router = APIRouter(tags=["ai"])


def get_ai_service() -> AiService:
    return AiService()


@router.get("/summaries/trends", response_model=TrendSummary)
async def get_trend_summary(
    category: str | None = Query(default=None),
    days: int = Query(default=7, ge=1, le=30),
    service: AiService = Depends(get_ai_service),
) -> TrendSummary:
    return await service.generate_trend_summary(category, days)


@router.post("/translations", response_model=TranslationTask)
async def create_translation(
    request: TranslationRequest,
    service: AiService = Depends(get_ai_service),
) -> TranslationTask:
    return await service.translate_summary(request)

