"""Domain error hierarchy and the RFC 9457 problem-details payload the API returns.

Every error the client can act on gets a stable machine-readable `code`; the
Flutter client branches on that code, never on the human-readable message.
"""

from __future__ import annotations

from typing import Any

from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse

from aber.core.logging import get_logger, request_id_var

log = get_logger(__name__)


class AberError(Exception):
    """Base for every error raised by our own code."""

    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    code: str = "internal_error"
    message: str = "An unexpected error occurred."

    def __init__(
        self,
        message: str | None = None,
        *,
        code: str | None = None,
        detail: dict[str, Any] | None = None,
    ) -> None:
        self.message = message or self.message
        self.code = code or self.code
        self.detail = detail or {}
        super().__init__(self.message)


class NotFoundError(AberError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"
    message = "The requested resource does not exist."


class ValidationError(AberError):
    status_code = 422
    code = "validation_error"
    message = "The request payload is invalid."


class AuthenticationError(AberError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthenticated"
    message = "Authentication is required."


class PermissionDeniedError(AberError):
    status_code = status.HTTP_403_FORBIDDEN
    code = "permission_denied"
    message = "You do not have permission to perform this action."


class ConflictError(AberError):
    """Raised when a write collides with a newer server state.

    The offline client relies on the `detail` payload carrying `server_state`
    and `conflicting_fields` so it can populate its conflicts inbox.
    """

    status_code = status.HTTP_409_CONFLICT
    code = "conflict"
    message = "This record changed on the server since you last saw it."


class UpstreamUnavailableError(AberError):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "upstream_unavailable"
    message = "A dependency is temporarily unavailable. The action was queued."


def _problem(status_code: int, code: str, message: str, detail: dict[str, Any]) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "code": code,
            "message": message,
            "detail": detail,
            "request_id": request_id_var.get(),
        },
    )


async def aber_error_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, AberError)
    if exc.status_code >= 500:
        log.error("unhandled_domain_error", code=exc.code, message=exc.message, exc_info=exc)
    else:
        log.info("domain_error", code=exc.code, message=exc.message)
    return _problem(exc.status_code, exc.code, exc.message, exc.detail)


async def http_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, HTTPException)
    return _problem(exc.status_code, "http_error", str(exc.detail), {})


async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    log.error("unhandled_exception", exc_info=exc)
    return _problem(
        status.HTTP_500_INTERNAL_SERVER_ERROR,
        "internal_error",
        "An unexpected error occurred.",
        {},
    )
