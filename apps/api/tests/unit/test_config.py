"""Configuration guards.

A production instance that boots with a missing signing key looks healthy right
up until the first login. Failing at startup instead is the whole point of these.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from aber.core.config import Environment, Settings

COMPLETE_PRODUCTION = {
    "env": Environment.PRODUCTION,
    "debug": False,
    "jwt_private_key_path": Path("/secrets/jwt_private.pem"),
    "jwt_public_key_path": Path("/secrets/jwt_public.pem"),
    "field_encryption_key": "a" * 44,
    "audit_signing_key_path": Path("/secrets/audit_signing.pem"),
    "s3_access_key": "key",
    "s3_secret_key": "secret",
}


class TestProductionGuards:
    def test_a_fully_configured_production_instance_validates(self) -> None:
        settings = Settings(**COMPLETE_PRODUCTION)
        assert settings.is_production

    @pytest.mark.parametrize(
        ("field", "env_var"),
        [
            ("jwt_private_key_path", "ABER_JWT_PRIVATE_KEY_PATH"),
            ("field_encryption_key", "ABER_FIELD_ENCRYPTION_KEY"),
            ("audit_signing_key_path", "ABER_AUDIT_SIGNING_KEY_PATH"),
            ("s3_secret_key", "ABER_S3_SECRET_KEY"),
        ],
    )
    def test_each_missing_secret_is_named_in_the_error(self, field: str, env_var: str) -> None:
        config = {**COMPLETE_PRODUCTION, field: None if "path" in field else ""}
        with pytest.raises(ValidationError, match=env_var):
            Settings(**config)

    def test_debug_mode_is_refused_in_production(self) -> None:
        with pytest.raises(ValidationError, match="ABER_DEBUG must be false"):
            Settings(**{**COMPLETE_PRODUCTION, "debug": True})

    def test_development_needs_no_secrets(self) -> None:
        # Otherwise every new engineer's first experience is a stack trace.
        settings = Settings(env=Environment.DEVELOPMENT)
        assert not settings.is_production
        assert settings.s3_secret_key == ""


class TestDatabaseUrlNormalisation:
    """Managed hosts hand out a bare postgresql:// URL. It must just work."""

    def test_bare_postgresql_url_gets_the_async_driver(self) -> None:
        settings = Settings(database_url="postgresql://u:p@db.host:5432/aber")
        assert str(settings.database_url).startswith("postgresql+asyncpg://")

    def test_heroku_style_postgres_scheme_is_upgraded(self) -> None:
        # Heroku still emits the long-deprecated `postgres://`.
        settings = Settings(database_url="postgres://u:p@db.host:5432/aber")
        assert str(settings.database_url).startswith("postgresql+asyncpg://")

    def test_an_explicit_async_driver_is_left_alone(self) -> None:
        settings = Settings(database_url="postgresql+asyncpg://u:p@db.host:5432/aber")
        assert str(settings.database_url).startswith("postgresql+asyncpg://")

    def test_sync_url_is_derived_from_the_async_one(self) -> None:
        settings = Settings(database_url="postgresql://u:p@db.host:5432/aber")
        assert str(settings.database_url_sync).startswith("postgresql+psycopg://")

    def test_derived_urls_address_the_same_database(self) -> None:
        # Migrating one database while serving another is the failure this
        # derivation exists to prevent.
        settings = Settings(database_url="postgresql://u:p@db.host:5432/aber")
        async_target = str(settings.database_url).split("://", 1)[1]
        sync_target = str(settings.database_url_sync).split("://", 1)[1]
        assert async_target == sync_target

    def test_an_explicit_sync_url_is_respected(self) -> None:
        settings = Settings(
            database_url="postgresql://u:p@primary:5432/aber",
            database_url_sync="postgresql+psycopg://u:p@replica:5432/aber",
        )
        assert "replica" in str(settings.database_url_sync)

    def test_credentials_and_query_parameters_survive(self) -> None:
        settings = Settings(database_url="postgresql://user:pa55@db.host:5432/aber?sslmode=require")
        rendered = str(settings.database_url)
        assert "user:pa55@db.host:5432" in rendered
        assert "sslmode=require" in rendered


class TestGeneralSettings:
    def test_log_level_is_normalised_to_upper_case(self) -> None:
        assert Settings(log_level="debug").log_level == "DEBUG"

    def test_storage_credentials_have_no_baked_in_default(self) -> None:
        # A default credential in source is one copied .env away from becoming
        # the production credential.
        settings = Settings()
        assert settings.s3_access_key == ""
        assert settings.s3_secret_key == ""

    def test_test_environment_is_recognised(self) -> None:
        assert Settings(env=Environment.TEST).is_testing
