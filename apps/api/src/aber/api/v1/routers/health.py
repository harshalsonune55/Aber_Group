"""Liveness and readiness endpoints.

`/health` answers "is the process up" and must never touch a dependency — it is
what the container healthcheck and the load balancer poll.

`/health/ready` answers "can this instance serve traffic" and does check
Postgres and Redis. Odoo is deliberately *not* part of readiness: the whole
architecture is built so the business keeps running while Odoo is down, so an
Odoo outage must not take our API out of rotation.
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
