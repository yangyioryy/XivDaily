"""add paper records"""

from alembic import op
import sqlalchemy as sa


revision = "0003_add_paper_records"
down_revision = "0002_add_trend_summary_cache"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "paper_records" not in inspector.get_table_names():
        op.create_table(
            "paper_records",
            sa.Column("paper_id", sa.String(length=64), nullable=False),
            sa.Column("title", sa.Text(), nullable=False),
            sa.Column("authors_json", sa.Text(), nullable=False),
            sa.Column("summary", sa.Text(), nullable=False),
            sa.Column("published_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.Column("categories_json", sa.Text(), nullable=False),
            sa.Column("primary_category", sa.String(length=64), nullable=False),
            sa.Column("source_url", sa.Text(), nullable=False),
            sa.Column("pdf_url", sa.Text(), nullable=False),
            sa.Column("synced_at", sa.DateTime(), nullable=False),
            sa.PrimaryKeyConstraint("paper_id"),
        )

    existing_indexes = {index["name"] for index in inspector.get_indexes("paper_records")}
    if "ix_paper_records_primary_category" not in existing_indexes:
        op.create_index("ix_paper_records_primary_category", "paper_records", ["primary_category"], unique=False)
    if "ix_paper_records_published_at" not in existing_indexes:
        op.create_index("ix_paper_records_published_at", "paper_records", ["published_at"], unique=False)
    if "ix_paper_records_synced_at" not in existing_indexes:
        op.create_index("ix_paper_records_synced_at", "paper_records", ["synced_at"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "paper_records" not in inspector.get_table_names():
        return

    existing_indexes = {index["name"] for index in inspector.get_indexes("paper_records")}
    if "ix_paper_records_synced_at" in existing_indexes:
        op.drop_index("ix_paper_records_synced_at", table_name="paper_records")
    if "ix_paper_records_published_at" in existing_indexes:
        op.drop_index("ix_paper_records_published_at", table_name="paper_records")
    if "ix_paper_records_primary_category" in existing_indexes:
        op.drop_index("ix_paper_records_primary_category", table_name="paper_records")
    op.drop_table("paper_records")
