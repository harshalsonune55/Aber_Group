"""FastAPI application factory."""

from __future__ import annotations

import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from aber.api.v1.routers import health
from aber.core.config import Settings, get_settings
from aber.core.errors import (
    AberError,
    aber_error_handler,
    http_exception_handler,
    unhandled_exception_handler,
)
from aber.core.logging import configure_logging, get_logger, request_id_var
from aber.db.session import dispose_engine

log = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings: Settings = app.state.settings
    log.info("api_starting", environment=settings.env.value, debug=settings.debug)
    yield
    await dispose_engine()
    log.info("api_stopped")


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(level=settings.log_level, json_output=settings.log_json)

    app = FastAPI(
        title="Aber Group API",
        description=(
            "Internal management platform for Aber Group — HR, properties, CRM, "
            "commissions, and the director transparency dashboard."
        ),
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs" if not settings.is_production else None,
        redoc_url=None,
        openapi_url="/openapi.json",
    )
    app.state.settings = settings

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    @app.middleware("http")
    async def request_context(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        # Honour a client-supplied id so a mobile bug report can be traced to a
        # server log line, but generate one when absent.
        rid = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        token = request_id_var.set(rid)
        try:
            response = await call_next(request)
        finally:
            request_id_var.reset(token)
        response.headers["X-Request-ID"] = rid
        return response

    app.add_exception_handler(AberError, aber_error_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)

    # Health lives at the root, outside the versioned prefix, so probes stay
    # stable across API versions.
    app.include_router(health.router)

    if settings.metrics_enabled:
        try:
            from prometheus_fastapi_instrumentator import Instrumentator

            Instrumentator().instrument(app).expose(app, include_in_schema=False)
        except ImportError:  # optional in local dev
            log.warning("metrics_unavailable", reason="prometheus_fastapi_instrumentator missing")

    return app


app = create_app()
