"""Liveness and readiness endpoints.

`/health` answers "is the process up" and must never touch a dependency — it is
what the container healthcheck and the load balancer poll.

`/health/ready` answers "can this instance serve traffic" and checks Postgres,
the one dependency the API cannot serve a request without.

Two deliberate exclusions:

* **Odoo.** The whole architecture is built so the business keeps running while
  Odoo is down; an Odoo outage must never take our API out of rotation.
* **Redis.** No request path touches it — it is the Celery broker, read only by
  the worker process. Failing readiness on it would take the API down for
  something that cannot affect a single HTTP response.

Both belong on the sync-health panel, not in a load balancer's rotation check.
"""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Response, status
from pydantic import BaseModel
from sqlalchemy import text

from aber.api.deps import SessionDep, SettingsDep
from aber.core.logging import get_logger

router = APIRouter(tags=["health"])
log = get_logger(__name__)


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str = "aber-api"
    version: str
    environment: str


class DependencyStatus(BaseModel):
    name: str
    healthy: bool
    detail: str | None = None


class ReadinessResponse(BaseModel):
    status: Literal["ready", "degraded"]
    dependencies: list[DependencyStatus]


@router.get("/health", response_model=HealthResponse, summary="Liveness probe")
async def health(settings: SettingsDep) -> HealthResponse:
    return HealthResponse(status="ok", version="0.1.0", environment=settings.env.value)


@router.get("/health/ready", response_model=ReadinessResponse, summary="Readiness probe")
async def readiness(response: Response, session: SessionDep) -> ReadinessResponse:
    deps: list[DependencyStatus] = []

    try:
        await session.execute(text("SELECT 1"))
        deps.append(DependencyStatus(name="postgres", healthy=True))
    except Exception as exc:
        log.warning("readiness_postgres_failed", error=str(exc))
        deps.append(DependencyStatus(name="postgres", healthy=False, detail=str(exc)))

    healthy = all(d.healthy for d in deps)
    if not healthy:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return ReadinessResponse(status="ready" if healthy else "degraded", dependencies=deps)
