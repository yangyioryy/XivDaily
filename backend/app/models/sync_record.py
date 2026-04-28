from datetime import datetime

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class SyncRecordModel(Base):
    """示例同步记录表，用于打通迁移与 SQLite 写入链路。"""

    __tablename__ = "sync_records"

    paper_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="not_synced")
    zotero_item_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    synced_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)

