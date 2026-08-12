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

## Current deployment

| | |
|---|---|
| API | https://aber-api.onrender.com |
| Blueprint | `render-minimal.yaml` (one Render slot) |
| Database | Neon, `eu-central-1` (Frankfurt), external to Render |
| Environment | `staging` |

Build the Android app against it with `make apk-hosted`.

Staging only — Neon and Render are both in Frankfurt, not the UAE. See the
residency note below before any real employee data is loaded.

## Option A — Render (fastest way to a live URL)

`render.yaml` in the repo root declares **two** resources: the API (web) and
Postgres, both in `frankfurt` — the closest Render region to the UAE. Deliberately
minimal, because Render caps resources per workspace and neither Redis nor a
worker is used yet.

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

### Why there is no worker, and no Redis

**Worker:** Render's free plan does not support background workers — `free` is
unavailable for private services, workers and cron jobs — and including one makes
the whole blueprint fail to apply.

**Redis / Key Value:** nothing in a request path touches it. It is the Celery
broker, read only by the worker process. The API serves fine without it, verified
by running the container with no `ABER_REDIS_URL` set at all. Provisioning it now
would consume a workspace slot for something unused.

Both arrive when there is background work to run, on a paid instance type.
Commented-out blocks for each sit at the bottom of `render.yaml`.

### "Additional services & databases will exceed limit of 25"

This is your Render **workspace**, not the blueprint. Render's Hobby plan caps a
workspace at 25 services, and the docs are explicit that this includes
**suspended** services. There is no way to raise the cap on Hobby.

**Fix A — free two slots.** At [dashboard.render.com](https://dashboard.render.com),
for each service you no longer need: **Settings → Delete**. Two easily missed
categories: services showing a *Suspended* badge, and free Postgres instances
that stopped working after their 90 days but are still listed.

**Fix B — need only one slot.** Use `render-minimal.yaml`, which declares the API
alone and takes its database from a free external provider.

1. Create a free Postgres at [neon.tech](https://neon.tech) (or Supabase). Choose
   a region near Frankfurt — every query pays the round trip.
2. Copy the connection string. It looks like
   `postgresql://user:pass@ep-xxx.eu-central-1.aws.neon.tech/aber?sslmode=require`.
3. Render → **New → Blueprint** → select the repo → set **Blueprint Path** to
   `render-minimal.yaml` → **Apply**.
4. When prompted for `ABER_DATABASE_URL`, paste the string **exactly as given**.

No editing of that URL is needed. The app rewrites the scheme onto asyncpg,
renames libpq's `sslmode` to asyncpg's `ssl`, and derives the psycopg URL Alembic
uses — see the SSL note below.

Switch back to `render.yaml` once slots are available; a managed database in the
same region as the API is the better arrangement.

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

**The SSL parameter is renamed automatically, and it has to be.** Neon, Supabase,
Render and Heroku all append `?sslmode=require` — libpq syntax. psycopg
understands it; **asyncpg does not**, and fails with
`TypeError: connect() got an unexpected keyword argument 'sslmode'`. The nasty
part is *when*: not at startup, but at the first database query. The container
starts, the `/health` liveness check passes, Render marks the deploy Live — and
then every real request fails. `Settings` renames it to asyncpg's `ssl` for the
async URL while leaving `sslmode` on the sync URL, so paste provider connection
strings unmodified.

**The port comes from the platform.** `scripts/start.sh` reads `$PORT`. A
hardcoded port means the platform's health check never connects and the deploy
fails with nothing useful in the logs.

**Production refuses to boot without secrets.** Missing `ABER_JWT_*`,
`ABER_FIELD_ENCRYPTION_KEY`, `ABER_AUDIT_SIGNING_KEY_PATH` or the S3
credentials raises at startup and names every missing variable. That is
deliberate: the alternative is an instance that looks healthy until the first
login or document upload.

**One system, nothing external to configure.** Postgres is the only dependency
a request touches, and readiness checks exactly that — see
[ADR 0006](../adr/0006-standalone-platform-no-odoo.md).
