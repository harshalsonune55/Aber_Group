"""Alembic environment.

Runs against the *sync* driver (psycopg) even though the app is async — Alembic
has no reason to be async, and the sync path keeps migration behaviour boring.

Autogenerate is a drafting aid only: every generated migration is hand-reviewed
before merge, and the history is forward-only.
"""

from __future__ import annotations

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from aber.core.config import get_settings
from aber.db.base import Base

# Importing the model modules populates Base.metadata. Every new model module
# must be imported here or autogenerate will silently propose dropping its table.
import aber.models  # noqa: F401  (side-effecting import)

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# An explicitly supplied URL wins — tests and one-off maintenance runs point
# Alembic at a specific database. Otherwise fall back to configured settings,
# so the common case needs no arguments.
if not config.get_main_option("sqlalchemy.url", None):
    config.set_main_option("sqlalchemy.url", str(get_settings().database_url_sync))

target_metadata = Base.metadata


def include_object(obj, name, type_, reflected, compare_to) -> bool:  # type: ignore[no-untyped-def]
    """Keep the audit schema out of autogenerate.

    ``audit`` is created and maintained by hand-written migrations because its
    append-only triggers and revoked grants are not expressible as SQLAlchemy
    models, and autogenerate would happily propose dropping them.
    """
    if type_ == "table" and getattr(obj, "schema", None) == "audit":
        return False
    return True


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_object=include_object,
            compare_type=True,
            compare_server_default=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
