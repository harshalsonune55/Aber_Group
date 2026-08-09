# syntax=docker/dockerfile:1.9
# Multi-stage: build wheels with the toolchain present, ship a slim runtime with
# no compiler and a non-root user.

FROM python:3.12-slim-bookworm AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir .


FROM python:3.12-slim-bookworm AS runtime

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 aber \
    && useradd --system --uid 1001 --gid aber --create-home aber

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=aber:aber alembic.ini ./
COPY --chown=aber:aber migrations ./migrations
COPY --chown=aber:aber src ./src
COPY --chown=aber:aber scripts ./scripts

RUN chmod +x scripts/start.sh

USER aber
EXPOSE 8000

# Liveness only — deliberately not /health/ready, because readiness checks
# dependencies and a transient Postgres blip should not kill the container.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT:-8000}/health" || exit 1

# start.sh reads $PORT, which managed platforms assign at runtime.
CMD ["./scripts/start.sh"]
