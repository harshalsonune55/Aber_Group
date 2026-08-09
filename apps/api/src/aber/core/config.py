"""Application settings, loaded from environment with the ABER_ prefix."""

from __future__ import annotations

from enum import StrEnum
from functools import lru_cache
from pathlib import Path

from pydantic import Field, PostgresDsn, RedisDsn, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Environment(StrEnum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TEST = "test"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="ABER_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Application ---
    env: Environment = Environment.DEVELOPMENT
    debug: bool = False
    log_level: str = "INFO"
    log_json: bool = False
    api_prefix: str = "/api/v1"
    cors_origins: list[str] = Field(default_factory=list)

    # --- Database ---
    # Pydantic validates these as DSNs but accepts a string literal as the
    # default; mypy sees only the declared type, hence the assignment ignores.
    database_url: PostgresDsn = "postgresql+asyncpg://aber:aber@localhost:5432/aber"  # type: ignore[assignment]
    database_url_sync: PostgresDsn = "postgresql+psycopg://aber:aber@localhost:5432/aber"  # type: ignore[assignment]
    db_pool_size: int = 10
    db_max_overflow: int = 20
    db_echo: bool = False

    # --- Redis / Celery ---
    # Separate logical databases so flushing the cache cannot drop queued jobs.
    redis_url: RedisDsn = "redis://localhost:6379/0"  # type: ignore[assignment]
    celery_broker_url: RedisDsn = "redis://localhost:6379/1"  # type: ignore[assignment]
    celery_result_backend: RedisDsn = "redis://localhost:6379/2"  # type: ignore[assignment]

    # --- Auth ---
    jwt_private_key_path: Path | None = None
    jwt_public_key_path: Path | None = None
    jwt_algorithm: str = "ES256"
    jwt_issuer: str = "aber-api"
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 30

    # --- Encryption / audit ---
    field_encryption_key: str = ""
    audit_signing_key_path: Path | None = None
    audit_signing_key_id: str = "v1"

    # --- Object storage ---
    # Credentials have no default: a baked-in secret is one copied .env away
    # from being the production credential. Supplied via environment; .env.example
    # carries the local MinIO values.
    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_region: str = "me-central-1"
    s3_bucket_documents: str = "aber-documents"
    s3_bucket_media: str = "aber-media"
    s3_presign_ttl_seconds: int = 900

    # --- Odoo ---
    odoo_url: str = "http://localhost:8069"
    odoo_db: str = "aber"
    odoo_username: str = "aber_integration"
    odoo_api_key: str = ""
    odoo_webhook_secret: str = ""
    odoo_timeout_connect: float = 5.0
    odoo_timeout_read: float = 30.0
    odoo_breaker_fail_max: int = 5
    odoo_breaker_reset_seconds: int = 60
    odoo_sync_enabled: bool = False
    odoo_sync_leads: bool = False

    # --- Notifications ---
    fcm_credentials_path: Path | None = None
    smtp_host: str = "localhost"
    smtp_port: int = 1025
    smtp_from: str = "no-reply@abergroup.ae"

    # --- Observability ---
    sentry_dsn: str = ""
    metrics_enabled: bool = True

    @field_validator("log_level")
    @classmethod
    def _upper(cls, v: str) -> str:
        return v.upper()

    @property
    def is_production(self) -> bool:
        return self.env is Environment.PRODUCTION

    @property
    def is_testing(self) -> bool:
        return self.env is Environment.TEST

    @model_validator(mode="after")
    def _require_secrets_in_production(self) -> Settings:
        """Refuse to start a production instance with missing secrets.

        Failing at boot is loud and obvious. The alternative is an instance that
        looks healthy until the first document upload or the first login, which
        is a far worse way to find out.
        """
        if not self.is_production:
            return self

        missing = [
            name
            for name, value in (
                ("ABER_JWT_PRIVATE_KEY_PATH", self.jwt_private_key_path),
                ("ABER_JWT_PUBLIC_KEY_PATH", self.jwt_public_key_path),
                ("ABER_FIELD_ENCRYPTION_KEY", self.field_encryption_key),
                ("ABER_AUDIT_SIGNING_KEY_PATH", self.audit_signing_key_path),
                ("ABER_S3_ACCESS_KEY", self.s3_access_key),
                ("ABER_S3_SECRET_KEY", self.s3_secret_key),
            )
            if not value
        ]
        if missing:
            raise ValueError("missing required production settings: " + ", ".join(missing))

        if self.debug:
            raise ValueError("ABER_DEBUG must be false in production")

        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
