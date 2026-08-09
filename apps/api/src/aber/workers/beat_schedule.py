"""Scheduled tasks.

Business rules are scheduled here rather than in Postgres cron so they live in
one place, are version-controlled, and can be tested.

Entries are commented out until the milestone that implements them lands, so
that beat never logs errors for tasks that do not yet exist.
"""

from __future__ import annotations

from typing import Any

from celery.schedules import crontab

BEAT_SCHEDULE: dict[str, dict[str, Any]] = {
    # --- M2: Odoo sync -------------------------------------------------------
    # "drain-outbox": {
    #     "task": "aber.workers.tasks.odoo_push.drain_outbox",
    #     "schedule": 15.0,
    # },
    # "pull-odoo-models": {
    #     "task": "aber.workers.tasks.odoo_pull.pull_all",
    #     "schedule": 300.0,
    # },
    # "odoo-health-probe": {
    #     "task": "aber.workers.tasks.odoo_pull.health_probe",
    #     "schedule": 60.0,
    # },
    # "nightly-reconcile": {
    #     "task": "aber.workers.tasks.odoo_pull.reconcile_all",
    #     # 03:00 GST, after the rollups so a drift repair shows in the morning.
    #     "schedule": crontab(hour=3, minute=0),
    # },
    #
    # --- M2: document expiry -------------------------------------------------
    # "document-expiry-alerts": {
    #     "task": "aber.workers.tasks.expiry_alerts.scan",
    #     # 07:00 GST so alerts land at the start of the working day, not overnight.
    #     "schedule": crontab(hour=7, minute=0),
    # },
    #
    # --- M7: dashboard rollups ----------------------------------------------
    # "nightly-rollups": {
    #     "task": "aber.workers.tasks.rollups.rebuild_all",
    #     "schedule": crontab(hour=2, minute=0),
    # },
    # "incremental-today-rollup": {
    #     "task": "aber.workers.tasks.rollups.refresh_today",
    #     "schedule": 600.0,
    # },
    # "daily-kpi-snapshot": {
    #     "task": "aber.workers.tasks.rollups.snapshot_kpis",
    #     "schedule": crontab(hour=23, minute=55),
    # },
    #
    # --- M1: audit chain -----------------------------------------------------
    # "daily-audit-anchor": {
    #     "task": "aber.workers.tasks.audit_anchor.sign_yesterday",
    #     "schedule": crontab(hour=0, minute=30),
    # },
}

__all__ = ["BEAT_SCHEDULE", "crontab"]
