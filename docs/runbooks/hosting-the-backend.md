# Runbook — hosting the backend

Two paths. Pick based on what the deployment is *for*.

| | Managed platform (Render/Railway) | UAE VPS with Docker |
|---|---|---|
| Good for | demos, staging, sharing a URL with the client | **production** |
| Setup time | minutes | a few hours |
| Data residency | ❌ no UAE region | ✅ in-country |
| Cost | free tier to start | ~$20–40/month |

## Why production cannot be Render

The platform stores employee passport and Emirates ID scans, salary figures,
bank IBANs and GPS attendance traces. Under UAE PDPL (Federal Decree-Law
45/2021) that data should stay in-country, and neither Render nor Railway nor
Fly has a UAE region. Use them to get something running and demoable; move to a
UAE host before real employee data is loaded. This is the same conclusion the
project plan reached, and nothing here changes it.

---

## Option A — Render (fastest way to a live URL)

`render.yaml` in the repo root declares three resources: the API (web), Postgres,
and a Key Value instance for Redis. All in `frankfurt`, which is the closest
Render region to the UAE.

1. Sign in at [render.com](https://render.com) with GitHub.
2. **New → Blueprint**, then authorise Render to read
   `harshalsonune55/Aber_Group` and select it.
3. Render parses `render.yaml` and lists the three resources. Click **Apply**.
4. First deploy takes 5–10 minutes — it builds the Docker image from
   `apps/api/Dockerfile`.
5. You get a URL like `https://aber-api.onrender.com`:

```bash
curl https://aber-api.onrender.com/health         # {"status":"ok",...}
curl https://aber-api.onrender.com/health/ready   # postgres healthy
open  https://aber-api.onrender.com/docs          # interactive API browser
```

Migrations run at container start (`RUN_MIGRATIONS_ON_START=true`). That is safe
with a single instance. With more than one, turn it off and run
`alembic upgrade head` as a pre-deploy command, or instances race applying the
same migration.

### Why there is no worker service

Render's free plan does not support background workers — `free` is unavailable
for private services, workers and cron jobs — and including one makes the whole
blueprint fail to apply. Nothing needs it yet: the Celery beat schedule is empty
until M2 brings the Odoo sync tasks. A commented-out worker block sits at the
bottom of `render.yaml`; enable it and move to a paid instance type when M2
lands.

### Free tier caveats

* The web service **sleeps after 15 minutes idle** and takes ~30 seconds to wake.
  The first request after a pause will look like a timeout in the app.
* Free Postgres instances are **deleted after 90 days**.
* 512 MB RAM, hence `WEB_CONCURRENCY=2`.

Fine for a demo. Not for a pilot with real users.

### Pointing the phone app at it

```bash
cd apps/app
flutter build apk --release \
  --dart-define=ABER_API_BASE_URL=https://aber-api.onrender.com
```

A hosted deployment is HTTPS, so the release build works without the cleartext
exemption that local development needs.

---

## Option B — UAE VPS (the production target)

Provider options in-region: AWS `me-central-1` (Dubai), Azure UAE North, or a
local provider. 2 vCPU / 4 GB is comfortable for 150 users.

```bash
# On the server
git clone https://github.com/harshalsonune55/Aber_Group.git
cd Aber_Group
cp .env.example .env
```

Generate real secrets — the app refuses to start in production without them:

```bash
mkdir -p secrets
openssl ecparam -genkey -name prime256v1 -noout -out secrets/jwt_private.pem
openssl ec -in secrets/jwt_private.pem -pubout -out secrets/jwt_public.pem
openssl genpkey -algorithm ed25519 -out secrets/audit_signing.pem
python3 -c "import os,base64;print(base64.b64encode(os.urandom(32)).decode())"
```

Put that last value in `ABER_FIELD_ENCRYPTION_KEY`, set `ABER_ENV=production`,
`ABER_DEBUG=false`, a strong `POSTGRES_PASSWORD`, MinIO credentials, and
`ABER_DOMAIN` to your real hostname. Then:

```bash
docker compose up -d
docker compose run --rm migrate
```

Caddy obtains a TLS certificate automatically for `ABER_DOMAIN` — point the
DNS A record at the server *before* starting it, or ACME validation fails.

### Before real data goes in

- **Back up.** `infra/backup/` has the pgBackRest scaffolding. An untested
  backup is not a backup — do a restore drill and time it.
- **Rotate the audit signing key off the server** into your secrets manager.
- **Firewall** everything except 80/443. Postgres, Redis and MinIO sit on the
  internal Docker network and must never be exposed.
- **Keep `secrets/` out of git.** It is already in `.gitignore`; verify with
  `git check-ignore -v secrets/jwt_private.pem`.

---

## Configuration notes that save an afternoon

**One database URL is enough.** Managed hosts emit `postgresql://…` (Heroku
still emits `postgres://`). `Settings` rewrites it onto `asyncpg` for the app
and derives the `psycopg` variant Alembic and Celery need. Setting
`ABER_DATABASE_URL_SYNC` separately is only for pointing migrations at a
different host, and letting the two drift means migrating one database while
serving another.

**The port comes from the platform.** `scripts/start.sh` reads `$PORT`. A
hardcoded port means the platform's health check never connects and the deploy
fails with nothing useful in the logs.

**Production refuses to boot without secrets.** Missing `ABER_JWT_*`,
`ABER_FIELD_ENCRYPTION_KEY`, `ABER_AUDIT_SIGNING_KEY_PATH` or the S3
credentials raises at startup and names every missing variable. That is
deliberate: the alternative is an instance that looks healthy until the first
login or document upload.

**Odoo stays off until M2.** `ABER_ODOO_SYNC_ENABLED=false`. Nothing in the
deploy depends on Odoo, and readiness deliberately excludes it — an Odoo outage
must never take the API out of rotation.
