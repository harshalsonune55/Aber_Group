"""The initial migration must produce a database the rest of the system assumes.

The audit-guard test is the important one here: the director-transparency
requirement rests on the claim that nobody — including the director, including a
compromised application role — can rewrite history. That claim is only as good
as this trigger, so it is asserted rather than trusted.
"""

from __future__ import annotations

import pytest
import sqlalchemy as sa
from sqlalchemy import Engine

pytestmark = pytest.mark.integration

REQUIRED_EXTENSIONS = {"pgcrypto", "pg_trgm", "ltree", "btree_gin"}


def test_required_extensions_are_installed(migrated_engine: Engine) -> None:
    with migrated_engine.connect() as conn:
        installed = {row[0] for row in conn.execute(sa.text("SELECT extname FROM pg_extension"))}
    assert installed >= REQUIRED_EXTENSIONS, f"missing: {REQUIRED_EXTENSIONS - installed}"


def test_audit_schema_exists(migrated_engine: Engine) -> None:
    with migrated_engine.connect() as conn:
        found = conn.execute(sa.text("SELECT 1 FROM pg_namespace WHERE nspname = 'audit'")).scalar()
    assert found == 1


def test_audit_guard_function_exists(migrated_engine: Engine) -> None:
    with migrated_engine.connect() as conn:
        found = conn.execute(
            sa.text(
                """
                SELECT 1 FROM pg_proc p
                JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'audit' AND p.proname = 'reject_mutation'
                """
            )
        ).scalar()
    assert found == 1


class TestAuditAppendOnlyGuard:
    """A table guarded by audit.reject_mutation must be genuinely append-only."""

    @pytest.fixture
    def guarded_table(self, migrated_engine: Engine):  # type: ignore[no-untyped-def]
        with migrated_engine.begin() as conn:
            conn.execute(sa.text("CREATE TABLE audit.guard_probe (id int PRIMARY KEY, value text)"))
            conn.execute(
                sa.text(
                    """
                    CREATE TRIGGER trg_guard_probe
                    BEFORE UPDATE OR DELETE ON audit.guard_probe
                    FOR EACH ROW EXECUTE FUNCTION audit.reject_mutation()
                    """
                )
            )
            conn.execute(sa.text("INSERT INTO audit.guard_probe VALUES (1, 'original')"))
        yield
        with migrated_engine.begin() as conn:
            conn.execute(sa.text("DROP TABLE IF EXISTS audit.guard_probe"))

    def test_insert_is_permitted(self, migrated_engine: Engine, guarded_table: None) -> None:
        with migrated_engine.begin() as conn:
            conn.execute(sa.text("INSERT INTO audit.guard_probe VALUES (2, 'appended')"))
            count = conn.execute(sa.text("SELECT count(*) FROM audit.guard_probe")).scalar()
        assert count == 2

    def test_update_is_rejected(self, migrated_engine: Engine, guarded_table: None) -> None:
        with (
            pytest.raises(sa.exc.DBAPIError, match="append-only"),
            migrated_engine.begin() as conn,
        ):
            conn.execute(sa.text("UPDATE audit.guard_probe SET value = 'tampered'"))

    def test_delete_is_rejected(self, migrated_engine: Engine, guarded_table: None) -> None:
        with (
            pytest.raises(sa.exc.DBAPIError, match="append-only"),
            migrated_engine.begin() as conn,
        ):
            conn.execute(sa.text("DELETE FROM audit.guard_probe"))

    def test_row_survives_a_rejected_tamper_attempt(
        self, migrated_engine: Engine, guarded_table: None
    ) -> None:
        with pytest.raises(sa.exc.DBAPIError), migrated_engine.begin() as conn:
            conn.execute(sa.text("UPDATE audit.guard_probe SET value = 'tampered'"))

        with migrated_engine.connect() as conn:
            value = conn.execute(
                sa.text("SELECT value FROM audit.guard_probe WHERE id = 1")
            ).scalar()
        assert value == "original"
