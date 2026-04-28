"""init sync records"""

from alembic import op
import sqlalchemy as sa


revision = "0001_init_sync_records"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sync_records",
        sa.Column("paper_id", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("zotero_item_key", sa.String(length=64), nullable=True),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("synced_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("paper_id"),
    )


def downgrade() -> None:
    op.drop_table("sync_records")

