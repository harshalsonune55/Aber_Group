"""Integration-test fixtures.

These need a real Postgres — the behaviour under test (extensions, triggers,
grants, RLS) does not exist in SQLite and cannot be mocked meaningfully.

Resolution order for the connection:
  1. ``ABER_TEST_DATABASE_URL`` if set (CI sets this to its service container);
  2. a testcontainers-managed Postgres if Docker is available;
  3. skip, with a message saying how to provide one.
"""

from __future__ import annotations

import os
from collections.abc import Iterator

import pytest
import sqlalchemy as sa
from sqlalchemy import Engine

pytestmark = pytest.mark.integration


def _container_url() -> str | None:
    try:
        from testcontainers.postgres import PostgresContainer
    except ImportError:
        return None
    try:
        container = PostgresContainer("postgres:16-alpine", driver="psycopg")
        container.start()
    except Exception:
        # Docker absent or not running — the caller falls through to a skip.
        return None
    pytest._aber_pg_container = container  # type: ignore[attr-defined]
    return container.get_connection_url()


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    url = os.environ.get("ABER_TEST_DATABASE_URL") or _container_url()
    if not url:
        pytest.skip(
            "no test database available — set ABER_TEST_DATABASE_URL "
            "(e.g. postgresql+psycopg://aber:aber@localhost:5432/aber_test) "
            "or start Docker for testcontainers"
        )
    yield url
    if container := getattr(pytest, "_aber_pg_container", None):
        container.stop()


@pytest.fixture(scope="session")
def engine(database_url: str) -> Iterator[Engine]:
    eng = sa.create_engine(database_url, poolclass=sa.pool.NullPool)
    yield eng
    eng.dispose()


@pytest.fixture(scope="session")
def migrated_engine(engine: Engine, database_url: str) -> Engine:
    """Apply the full Alembic history.

    Running the real migrations rather than ``metadata.create_all`` means the
    migrations themselves are under test — a migration that works only on an
    empty database gets caught here rather than on the production server.
    """
    from pathlib import Path

    from alembic import command
    from alembic.config import Config

    # Anchored to the package root so the suite runs from any working directory.
    api_root = Path(__file__).resolve().parents[2]
    cfg = Config(str(api_root / "alembic.ini"))
    cfg.set_main_option("script_location", str(api_root / "migrations"))
    cfg.set_main_option("sqlalchemy.url", database_url)
    command.upgrade(cfg, "head")
    return engine
