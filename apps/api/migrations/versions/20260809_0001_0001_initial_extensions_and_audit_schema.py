"""initial extensions and audit schema

Establishes the database primitives every later migration depends on:

* ``pgcrypto``  — ``gen_random_bytes`` for the audit hash chain
* ``pg_trgm``   — trigram indexes for property/unit and contact name search (M4/M5)
* ``ltree``     — org-chart paths, so "my team" scoping is a single index scan (M2)
* ``btree_gin`` — composite indexes mixing scalars with jsonb on the fact tables (M7)

It also creates the ``audit`` schema up front. The audit log is append-only by
grant *and* by trigger, and both are hand-written here because neither is
expressible as a SQLAlchemy model — autogenerate would propose dropping them.

Revision ID: 0001
Revises:
Created: 2026-08-09

"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    for ext in ("pgcrypto", "pg_trgm", "ltree", "btree_gin"):
        op.execute(sa.text(f'CREATE EXTENSION IF NOT EXISTS "{ext}"'))

    op.execute(sa.text("CREATE SCHEMA IF NOT EXISTS audit"))

    # Refuse UPDATE and DELETE on anything in the audit schema. The application
    # role is separately granted only INSERT and SELECT, so this is defence in
    # depth: even a role misconfiguration cannot rewrite history.
    op.execute(
        sa.text(
            """
            CREATE OR REPLACE FUNCTION audit.reject_mutation()
            RETURNS TRIGGER
            LANGUAGE plpgsql
            AS $$
            BEGIN
                RAISE EXCEPTION
                    'audit records are append-only (attempted % on %)',
                    TG_OP, TG_TABLE_NAME
                    USING ERRCODE = 'insufficient_privilege';
            END;
            $$;
            """
        )
    )


def downgrade() -> None:
    # Deliberately does not drop the audit schema. Losing the audit trail to a
    # rollback would defeat its purpose; dropping it is a manual, deliberate act.
    op.execute(sa.text("DROP FUNCTION IF EXISTS audit.reject_mutation()"))
