"""Shared FastAPI dependencies.

Settings are resolved from ``request.app.state`` rather than the cached global
``get_settings()``. Tests build an app with an explicit ``Settings`` instance,
and reading the global would silently ignore it — the endpoint would report the
developer's real environment while under test.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from aber.core.config import Settings
from aber.db.session import get_session


def settings_dep(request: Request) -> Settings:
    return request.app.state.settings  # type: ignore[no-any-return]


SettingsDep = Annotated[Settings, Depends(settings_dep)]
SessionDep = Annotated[AsyncSession, Depends(get_session)]
