from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.health import router as health_router
from app.api.papers import router as papers_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.db.session import ensure_database_parent_dir

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    # 启动时先准备日志和 SQLite 目录，保证后续数据库初始化可落盘。
    configure_logging(settings.app_log_level)
    ensure_database_parent_dir()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    register_exception_handlers(app)
    app.include_router(health_router)
    app.include_router(papers_router)
    return app


app = create_app()
