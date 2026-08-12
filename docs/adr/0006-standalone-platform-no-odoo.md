# ADR 0006 — Standalone platform: no Odoo

**Status:** Accepted · **Date:** 2026-08-13
**Supersedes:** [ADR 0001](0001-own-backend-with-odoo-sync.md),
[ADR 0004](0004-odoo-sync-contract.md)

## Context

ADR 0001 chose "our own backend, synced with Odoo": our Postgres owning the
real-estate domain, Odoo owning accounting, payroll and partners-as-financial-
entities. ADR 0004 then specified the sync in detail — field-level ownership,
a transactional outbox, `x_aber_uuid` adopt-then-create, two independent change
channels, nightly reconciliation.

None of it was built. At the point of this decision the integration is:

* `integrations/odoo/__init__.py` — empty
* `integrations/odoo/mappers/__init__.py` — empty
* `contracts.py`, the file ADR 0004 names as the enforcement mechanism — absent
* `odoo/addons/` — empty
* `tests/odoo/` — empty

So the cost of walking away is the two ADRs and some scaffolding, not working
code. That is the cheapest this decision will ever be, and it gets more
expensive from M2 onwards.

## Decision

**One system. Our Postgres is the system of record for everything.** No Odoo,
no sync engine, no anti-corruption layer, no second database to keep
consistent.

The functionality Odoo was going to provide — payroll, invoicing, the general
ledger, VAT — is either built here or handed to a purpose-built service later
through an ordinary integration. It is not adopted as a second system of
record.

## Consequences

**We gain:**

* The central risk of the project disappears. ADR 0001 named keeping two
  systems consistent as *"the central risk of this project"*. It is now not a
  risk, because there is only one system.
* Everything ADR 0001 listed as a *gain* of owning our domain now applies to
  the whole platform, not just the real-estate half: one data model, one audit
  log, one offline story, no field-ownership negotiation.
* A large amount of machinery is never written: outbox drain, pull sweeps,
  circuit breaker, reconciliation, conflict inbox for sync, two Celery queues,
  a second Postgres, an Odoo container in every environment.
* Deployment gets materially smaller and cheaper — no Odoo instance, no second
  database.

**We accept — and this is the real cost:**

* **UAE payroll is now ours to build.** WPS SIF file generation, end-of-service
  gratuity under the UAE Labour Law, and air-ticket/leave-salary accruals.
  Odoo's `hr` modules do this today; we would be writing and, more importantly,
  *maintaining* it against regulation that changes.
* **Accounting is now ours.** Invoices, the general ledger, VAT at 5% and the
  FTA return. This is the part where being wrong has consequences with a
  regulator rather than with a user.
* **No accountant-facing UI for free.** Odoo ships one their finance staff
  could have used on day one.

These three are why ADR 0001 chose Odoo in the first place. Dropping it is a
sound decision *if* the plan is to keep payroll and accounting outside the
platform — in a payroll bureau, an accountant's own software, or a dedicated
service integrated later — and to treat this platform as the operations system
it actually is: HR operations, properties, CRM, deals, commissions, attendance
and the director's dashboard.

It is not a sound decision if the intent is to reimplement WPS and a general
ledger from scratch. That is a product in its own right, and a regulated one.

**Bearing on ADR 0002:** the choice of Python/FastAPI rested partly on *"we must
write Odoo addons anyway"*. That argument is void. ADR 0002 stands on its
remaining reasons — the team's Python skills, regional hiring, and the
async/offline fit — and is not reopened, because switching language now would
cost far more than the weakened rationale is worth.

## What replaces the sync roadmap

M2 was "HR core + first Odoo pull". It becomes HR core alone. The `sync` model
package (`odoo_link`, `odoo_sync_cursor`, `outbox_event`, `sync_conflict`) is
dropped from the schema roadmap.

The transactional outbox is worth keeping in mind, though not for sync: the
same pattern serves push notifications and any future third-party integration,
and can be reintroduced when one exists to serve.
