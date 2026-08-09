#!/usr/bin/env sh
# Container entrypoint for hosted deployments.
#
# Managed platforms (Render, Railway, Fly, Cloud Run, Heroku) assign a port at
# runtime through $PORT and route to it. A hardcoded port means the platform's
# health check never connects and the deploy is marked failed with no useful
# log line, so the port is read from the environment here.

set -eu

PORT="${PORT:-8000}"
WORKERS="${WEB_CONCURRENCY:-4}"

# In the container the package is installed normally and this is a no-op.
# It matters when the script is run from a source checkout, where an editable
# install's .pth file cannot be relied on.
if [ -d "$(dirname "$0")/../src" ]; then
    SRC="$(cd "$(dirname "$0")/../src" && pwd)"
    PYTHONPATH="${SRC}${PYTHONPATH:+:${PYTHONPATH}}"
    export PYTHONPATH
fi

# Applying migrations at boot is convenient for a single-instance deploy, but it
# races when several instances start at once. Platforms with a release/pre-deploy
# hook should run `alembic upgrade head` there instead and set this to false.
if [ "${RUN_MIGRATIONS_ON_START:-true}" = "true" ]; then
    echo "==> applying database migrations"
    alembic upgrade head
fi

echo "==> starting uvicorn on 0.0.0.0:${PORT} with ${WORKERS} workers"
exec uvicorn aber.main:app \
    --host 0.0.0.0 \
    --port "${PORT}" \
    --workers "${WORKERS}" \
    --proxy-headers \
    --forwarded-allow-ips '*'
