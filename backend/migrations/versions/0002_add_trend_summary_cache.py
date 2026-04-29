"""add trend summary cache"""

from alembic import op
import sqlalchemy as sa


revision = "0002_add_trend_summary_cache"
down_revision = "0001_init_sync_records"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trend_summary_cache",
        sa.Column("cache_key", sa.String(length=128), nullable=False),
        sa.Column("category", sa.String(length=64), nullable=False),
        sa.Column("days", sa.Integer(), nullable=False),
        sa.Column("window_start", sa.DateTime(), nullable=False),
        sa.Column("window_end", sa.DateTime(), nullable=False),
        sa.Column("intro", sa.Text(), nullable=False),
        sa.Column("items_json", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("warning", sa.Text(), nullable=True),
        sa.Column("generated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("cache_key"),
    )


def downgrade() -> None:
    op.drop_table("trend_summary_cache")
