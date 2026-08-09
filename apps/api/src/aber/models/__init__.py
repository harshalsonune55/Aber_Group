"""SQLAlchemy model registry.

Importing this package must import every model module, because Alembic's
autogenerate compares ``Base.metadata`` against the live database — a model
that is never imported looks like a table that should be dropped.

Modules are added here as each milestone lands:
    identity   (M1)  users, roles, permissions, devices, refresh tokens
    audit      (M1)  audit_log, audit_anchor
    hr         (M2)  employees, departments, documents, attendance, leave
    sync       (M2)  odoo_link, odoo_sync_cursor, outbox_event, sync_conflict
    property   (M4)  developers, projects, properties, media
    crm        (M5)  partners, leads, viewings, deals
    commission (M6)  plans, rules, runs, entries, payouts
    analytics  (M7)  fact_* rollups, kpi_snapshot
"""

from __future__ import annotations

from aber.db.base import Base

__all__ = ["Base"]
