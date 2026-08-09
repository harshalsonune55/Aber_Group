from __future__ import annotations

import os
from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from aber.core.config import Environment, Settings
from aber.main import create_app

# Read by the integration fixtures rather than by Settings, so it must survive
# the environment scrubbing below.
_PRESERVED_ENV = {"ABER_TEST_DATABASE_URL"}


@pytest.fixture(autouse=True)
def hermetic_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    """Isolate tests from the developer's own configuration.

    Without this, `Settings()` picks up apps/api/.env and every assertion about
    defaults silently depends on whatever the person running the suite happens
    to have configured — passing on their machine and failing in CI, or worse,
    the reverse.
    """
    for key in list(os.environ):
        if key.startswith("ABER_") and key not in _PRESERVED_ENV:
            monkeypatch.delenv(key, raising=False)

    # pydantic-settings reads `.env` from the working directory by default.
    # model_config is a TypedDict, so this is an item, not an attribute.
    monkeypatch.setitem(Settings.model_config, "env_file", None)


@pytest.fixture(scope="session")
def settings() -> Settings:
    return Settings(
        env=Environment.TEST,
        debug=True,
        metrics_enabled=False,
        log_level="WARNING",
        _env_file=None,
    )


@pytest.fixture(scope="session")
def app(settings: Settings) -> FastAPI:
    return create_app(settings)


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app) as c:
        yield c
