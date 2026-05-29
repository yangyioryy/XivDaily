import asyncio
import os
from contextlib import asynccontextmanager
from contextlib import suppress

from fastapi import FastAPI

from app.api.ai import router as ai_router
from app.api.config import router as config_router
from app.api.health import router as health_router
from app.api.papers import router as papers_router
from app.api.zotero import router as zotero_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.db.session import ensure_database_parent_dir
from app.services.paper_sync_service import PaperSyncService

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    # 启动时先准备日志和 SQLite 目录，保证后续数据库初始化可落盘。
    configure_logging(settings.app_log_level)
    ensure_database_parent_dir()
    stop_event = asyncio.Event()
    sync_task: asyncio.Task[None] | None = None
    if settings.arxiv_sync_enabled and "PYTEST_CURRENT_TEST" not in os.environ:
        sync_task = asyncio.create_task(PaperSyncService().run_periodic(stop_event))
    yield
    stop_event.set()
    if sync_task is not None:
        sync_task.cancel()
        with suppress(asyncio.CancelledError):
            await sync_task


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    register_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(papers_router)
    app.include_router(ai_router)
    app.include_router(config_router)
    app.include_router(zotero_router)
    return app


app = create_app()
