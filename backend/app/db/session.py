from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings

settings = get_settings()

connect_args: dict[str, object] = {}
if settings.database_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(settings.database_url, connect_args=connect_args, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, class_=Session)


def ensure_database_parent_dir() -> None:
    """SQLite 以本地文件形式运行时，启动前先确保目录存在。"""
    sqlite_path = settings.sqlite_path
    if sqlite_path is None:
        return
    if not sqlite_path.is_absolute():
        sqlite_path = Path.cwd() / sqlite_path
    sqlite_path.parent.mkdir(parents=True, exist_ok=True)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

