from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TrendSummaryCacheModel(Base):
    """按领域和固定三天窗口缓存趋势简报，避免重复触发 LLM。"""

    __tablename__ = "trend_summary_cache"

    cache_key: Mapped[str] = mapped_column(String(128), primary_key=True)
    category: Mapped[str] = mapped_column(String(64), nullable=False, default="")
    days: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    window_start: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    window_end: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    intro: Mapped[str] = mapped_column(Text, nullable=False)
    items_json: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="success")
    warning: Mapped[str | None] = mapped_column(Text, nullable=True)
    generated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
