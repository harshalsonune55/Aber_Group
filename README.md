# Aber Group — Internal Management Platform

Internal platform for a UAE real-estate company: HR, properties, CRM and
commissions, feeding a director transparency dashboard, delivered as one
Flutter app for Android, iOS, Windows, macOS and Linux.

**Status: M0 complete** — the walking skeleton runs. See [build order](#build-order).

## Architecture

```
┌──────────── Flutter client (Android / iOS / Windows / macOS / Linux) ───────┐
│  Riverpod + go_router + Drift(SQLCipher) offline cache + mutation queue     │
└───────────────┬──────────────────────────────────────────┬─────────────────┘
                │ HTTPS/JSON (REST + SSE)                   │ presigned PUT
                ▼                                           ▼
        ┌───────────────┐   ┌──────────┐   ┌────────┐   ┌────────────┐
        │  FastAPI API  │──▶│  Redis   │◀──│ Celery │   │   MinIO    │
        └──────┬────────┘   └──────────┘   └────────┘   └────────────┘
               ▼
        ┌────────────────┐
        │ Postgres 16    │
        │ app + audit    │
        └────────────────┘
                    all behind Caddy 2 (TLS) on one UAE VPS
```

**One system of record.** Our Postgres holds everything — HR, properties, CRM,
deals, commissions, attendance and the audit log. There is no second system to
stay consistent with, which removes what ADR 0001 called the central risk of the
project. See [ADR 0006](docs/adr/0006-standalone-platform-no-odoo.md), which
supersedes ADR 0001 and ADR 0004.

## Getting started

Requirements: Python 3.12, Flutter 3.44+, PostgreSQL 14+, Redis. Docker is
needed for deployment, but not for day-to-day backend or Flutter work — the
tests run against a local Postgres.

```bash
make bootstrap      # venv, dependencies, Flutter packages, .env
make db-create      # local aber and aber_test databases
make migrate        # apply migrations
make dev            # API on http://localhost:8000
```

In another terminal:

```bash
make app-macos      # or app-android / app-windows / app-linux / app-ios
```

The app opens on the **System status** screen, which reports whether it can
reach the backend — the M0 walking skeleton, kept afterwards as a support page.

## Testing

Four commands need nothing running but Postgres:

```bash
make test               # 36 backend unit tests — money, ids, config, health
make test-integration   # 7 tests against real Postgres, incl. the audit-guard proof
make app-test           # 28 Flutter unit + widget tests
make lint               # ruff check, ruff format --check, mypy
```

One more talks to the hosted API by default:

```bash
make app-test-live      # real Dart client → real API → real Postgres, over a socket
```

Override `API_URL` to point the same check at a local or staging backend:

```bash
make app-test-live API_URL=http://127.0.0.1:8000
```

If that backend is not reachable, the test fails rather than passing silently.

### What each layer actually covers

| Command | Proves |
|---|---|
| `make test` | Commission splits never lose or invent a fil (400 generated cases via Hypothesis); floats are rejected at the money boundary; UUIDv7 ids are unique and time-ordered; a production config with a missing secret refuses to boot. |
| `make test-integration` | The migration produces the extensions and audit schema the system assumes, and **a guarded audit table genuinely rejects `UPDATE` and `DELETE`** — the trigger the director-transparency guarantee rests on. Runs the real Alembic history, so the migrations are under test too. |
| `make app-test` | Breakpoints classify phone/tablet/laptop widths correctly; the shell shows bottom navigation on a phone and a rail on a desktop; every mutating request carries an `Idempotency-Key`; a dropped connection maps to a retryable failure rather than an exception. |
| `make app-test-live` | The client, its interceptors and FastAPI interoperate for real — not with a stub written to match our own assumptions. |

### Manual check

```bash
make dev
curl localhost:8000/health        # {"status":"ok",...}
curl localhost:8000/health/ready  # postgres healthy
open http://localhost:8000/docs   # interactive API browser
```

### Not runnable on this machine yet

Native app builds (`make app-macos`, `app-android`, …) need full Xcode and
completed Android SDK tooling; until then CI builds those on every push. See
[docs/runbooks](docs/runbooks/).

## Hosting the backend

Fastest route to a live URL: Render → **New → Blueprint** → select this repo.
`render.yaml` provisions two resources — the API and Postgres — and migrations run
on start. No Redis and no Celery worker: neither is on a request path, Render's
free plan does not allow workers at all, and neither is needed until there is
background work to run.

```bash
curl https://<your-service>.onrender.com/health
```

**Render is for demos and staging, not production.** It has no UAE region, and
this platform stores passport scans, Emirates ID numbers, salary figures and GPS
attendance. Production runs on a UAE-region host — see
[docs/runbooks/hosting-the-backend.md](docs/runbooks/hosting-the-backend.md) for
both paths, including the `docker compose` deployment and the secrets you must
generate first.

Only `ABER_DATABASE_URL` needs setting; the app rewrites a bare `postgresql://`
onto the async driver and derives the sync URL that Alembic and Celery use.

## Layout

| Path | Contents |
|---|---|
| `apps/api/` | FastAPI backend. `domain/` is pure logic with no I/O; `services/` orchestrates; `integrations/` holds outbound adapters (storage, push). |
| `apps/app/` | Flutter client, all five platforms. |
| `packages/api_client/` | Dart client generated from the OpenAPI schema — never hand-edited. |
| `infra/` | Caddy, Postgres, MinIO, observability, backup, deploy. |
| `docs/adr/` | Architecture decision records. Read these first. |

## Build order

| | Milestone | Status |
|---|---|---|
| M0 | Foundations and walking skeleton | **done** |
| M1 | Identity, RBAC, audit spine | next |
| M2 | HR core | |
| M3 | Attendance, leave, offline sync engine | |
| M4 | Properties and listings | |
| M5 | CRM: lead → viewing → deal | |
| M6 | Commission engine | |
| M7 | Director transparency dashboard | |
| M8 | Hardening, compliance, operations | |
| M9 | Data migration, UAT, pilot rollout | |

Identity comes first because every later milestone writes audit rows against a
user, and retrofitting an actor onto an existing audit trail is not something
you get to do twice.

## Conventions

* **No floats in monetary code, anywhere.** `Decimal` on the backend,
  `numeric(18,4)` in Postgres. A commission rounding error is money owed to a
  real person.
* **UUIDv7 primary keys, generatable by an offline client** — see
  [ADR 0003](docs/adr/0003-riverpod-and-offline-first.md).
* **Nothing the business has acted on is ever hard-deleted** — soft delete
  only, so the audit trail always has something to point at.
* **Every write goes through the service layer**, because that is what writes the
  audit log — see [ADR 0005](docs/adr/0005-audit-chain-and-rtl-readiness.md).
* **UI is English but built RTL-safe**, so Arabic later is a translation job.

## Compliance

The platform handles employee passport and Emirates ID scans, salary data and
GPS attendance. It is hosted in a UAE region; UAE PDPL (Federal Decree-Law
45/2021) documentation lives in `docs/data-protection/`. GPS is captured only at
explicit check-in and viewing check-in — never continuously — and that is stated
in the UI.
