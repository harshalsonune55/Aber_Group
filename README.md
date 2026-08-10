# Aber Group — Internal Management Platform

Internal platform for a UAE real-estate company: HR, properties, CRM and
commissions, feeding a director transparency dashboard, synced with a
self-hosted Odoo, delivered as one Flutter app for Android, iOS, Windows, macOS
and Linux.

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
        └──────┬────────┘   └──────────┘   └───┬────┘   └────────────┘
               ▼                                │ JSON-RPC
        ┌────────────────┐                      ▼
        │ Postgres 16    │◀─ webhook hint ─┌──────────────────┐
        │ app + audit    │   (HMAC signed) │ Odoo 18 Community│
        └────────────────┘                 └──────────────────┘
                    all behind Caddy 2 (TLS) on one UAE VPS
```

Our Postgres is the system of record for the real-estate domain. Odoo is the
system of record for accounting and payroll. Every cross-boundary write goes
through a transactional outbox, and **no user-facing request ever blocks on
Odoo** — see [ADR 0001](docs/adr/0001-own-backend-with-odoo-sync.md) and
[ADR 0004](docs/adr/0004-odoo-sync-contract.md).

## Getting started

Requirements: Python 3.12, Flutter 3.44+, PostgreSQL 14+, Redis. Docker is
needed for the Odoo integration tests and for deployment, but not for day-to-day
backend or Flutter work.

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

One more needs the API up. In one terminal `make dev`, then:

```bash
make app-test-live      # real Dart client → real API → real Postgres, over a socket
```

If the backend is not running it fails with
`No backend at http://127.0.0.1:8000 — start it with 'make dev'` rather than
passing silently.

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

`make test-odoo` needs Docker for a dockerised Odoo 18 — it becomes relevant at
M2. Native app builds (`make app-macos`, `app-android`, …) need full Xcode and
completed Android SDK tooling; until then CI builds those on every push. See
[docs/runbooks](docs/runbooks/).

## Hosting the backend

Fastest route to a live URL: Render → **New → Blueprint** → select this repo.
`render.yaml` provisions two resources — the API and Postgres — and migrations run
on start. No Redis and no Celery worker: neither is on a request path, Render's
free plan does not allow workers at all, and both arrive with the Odoo sync tasks
in M2.

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
| `apps/api/` | FastAPI backend. `domain/` is pure logic with no I/O; `services/` orchestrates; `integrations/odoo/` is the anti-corruption layer. |
| `apps/app/` | Flutter client, all five platforms. |
| `packages/api_client/` | Dart client generated from the OpenAPI schema — never hand-edited. |
| `odoo/addons/` | `aber_sync` and `aber_realestate_bridge` custom addons. |
| `infra/` | Caddy, Postgres, MinIO, observability, backup, deploy. |
| `docs/adr/` | Architecture decision records. Read these first. |

## Build order

| | Milestone | Status |
|---|---|---|
| M0 | Foundations and walking skeleton | **done** |
| M1 | Identity, RBAC, audit spine | next |
| M2 | HR core + first Odoo pull | |
| M3 | Attendance, leave, offline sync engine | |
| M4 | Properties and listings | |
| M5 | CRM: lead → viewing → deal | |
| M6 | Commission engine + Odoo deal/invoice push | |
| M7 | Director transparency dashboard | |
| M8 | Hardening, compliance, operations | |
| M9 | Data migration, UAT, pilot rollout | |

Odoo integration is proven in M2 rather than deferred, because it is the highest-
uncertainty part of the system and the cheapest time to discover a problem with
it is early.

## Conventions

* **No floats in monetary code, anywhere.** `Decimal` on the backend,
  `numeric(18,4)` in Postgres. A commission rounding error is money owed to a
  real person.
* **UUIDv7 primary keys, generatable by an offline client** — see
  [ADR 0003](docs/adr/0003-riverpod-and-offline-first.md).
* **Nothing that has crossed the Odoo boundary is ever hard-deleted.**
* **Every write goes through the service layer**, because that is what writes the
  audit log — see [ADR 0005](docs/adr/0005-audit-chain-and-rtl-readiness.md).
* **UI is English but built RTL-safe**, so Arabic later is a translation job.

## Compliance

The platform handles employee passport and Emirates ID scans, salary data and
GPS attendance. It is hosted in a UAE region; UAE PDPL (Federal Decree-Law
45/2021) documentation lives in `docs/data-protection/`. GPS is captured only at
explicit check-in and viewing check-in — never continuously — and that is stated
in the UI.
