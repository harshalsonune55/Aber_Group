"""Celery application.

Queues are separated so a slow or wedged Odoo cannot starve user-facing work
such as notifications. In particular ``odoo_push`` and ``odoo_pull`` are
isolated: when the Odoo circuit breaker is open those queues back up harmlessly
while ``notify`` and ``default`` keep flowing.
"""

from __future__ import annotations

from celery import Celery

from aber.core.config import get_settings


def create_celery() -> Celery:
    settings = get_settings()

    celery = Celery(
        "aber",
        broker=str(settings.celery_broker_url),
        backend=str(settings.celery_result_backend),
        include=["aber.workers.tasks"],
    )

    celery.conf.update(
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="Asia/Dubai",
        enable_utc=True,
        task_track_started=True,
        task_acks_late=True,
        # A worker crash mid-task must not silently drop the task; combined with
        # acks_late this makes redelivery the default rather than loss.
        task_reject_on_worker_lost=True,
        worker_prefetch_multiplier=1,
        task_time_limit=600,
        task_soft_time_limit=540,
        result_expires=86400,
        task_default_queue="default",
        task_routes={
            "aber.workers.tasks.odoo_push.*": {"queue": "odoo_push"},
            "aber.workers.tasks.odoo_pull.*": {"queue": "odoo_pull"},
            "aber.workers.tasks.notifications.*": {"queue": "notify"},
            "aber.workers.tasks.rollups.*": {"queue": "reports"},
        },
        redbeat_redis_url=str(settings.celery_broker_url),
        beat_scheduler="redbeat.RedBeatScheduler",
    )

    from aber.workers.beat_schedule import BEAT_SCHEDULE

    celery.conf.beat_schedule = BEAT_SCHEDULE
    return celery


celery_app = create_celery()
