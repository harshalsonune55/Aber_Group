# ADR 0004 — Field-level ownership as executable code

**Status:** Superseded by [ADR 0006](0006-standalone-platform-no-odoo.md) ·
**Date:** 2026-08-09

> Never implemented. Kept because the technique — declaring field ownership as
> a dict the writer asserts against, rather than as prose — is worth reaching
> for the next time this platform has to stay consistent with a system it does
> not own. Today it owns everything, so there is nothing to negotiate.

## Context

Two systems holding overlapping data will drift. The overwhelmingly common cause
is not clock skew or network failure — it is that **both systems are allowed to
write the same field**, and the last writer silently wins.

## Decision

1. `integrations/odoo/contracts.py` declares, per Odoo model and per field, which
   system owns it. **The sync engine refuses to write a field it does not own.**
   That is a hard assertion that raises, not a policy document.
2. `docs/odoo-field-ownership.md` is generated from that dict in CI, so the
   documentation cannot drift from the behaviour.
3. Odoo integration is proven in **M2**, the third milestone, not near the end.

## Ownership summary

| Entity | Owner | Notes |
|---|---|---|
| `hr.employee`, `hr.department`, `hr.job` | Odoo | Payroll, WPS and gratuity already live there. HR creates employees in Odoo; we mirror and extend. |
| `hr.contract` | Odoo | Read-only for us; salary is RLS-protected on our side. |
| `hr.attendance`, `hr.leave` | Us | GPS capture is our differentiator. We push approved leave and closed attendance days; we pull `hr.leave.state` back in case HR overrides. |
| `res.partner` | Split | We own contact and CRM fields; Odoo owns TRN/VAT, payment terms and receivable account. The only genuinely bidirectional entity — the field split is what makes it safe. |
| `sale.order`, `account.move` | Us at creation | We push on deal close; Odoo owns `state`, `payment_state` and the invoice number. **We never compute accounting numbers.** |
| `crm.lead` | Not synced | See below. |
| `product.product` | Us, lazily | Created only when a unit is actually invoiced. |

## Two opinionated exclusions

**Leads are not synced.** Odoo's CRM has its own stage machinery, lost-reason
model and activity scheduler that would fight ours, and accounting needs the
*deal*, not the funnel. Syncing leads would roughly double the sync surface for
no financial benefit. Behind `ODOO_SYNC_LEADS`, defaulting to false.

**Properties are not mirrored as products.** Pushing thousands of units into
Odoo's product master is useless there and creates a large sync surface. Most
deals bill against a generic "Agency Commission" service product.

## Supporting mechanisms

* **Transactional outbox** — the event is written in the same transaction as the
  business change, so a crash mid-push loses nothing and there is no dual write.
* **`x_aber_uuid`** — our UUID on every mirrored Odoo record, uniquely indexed.
  Push handlers look up, then *adopt* an existing record, then create. Two
  workers racing cannot duplicate: the second `create` fails on the constraint
  and retries into the adopt branch.
* **Two independent change channels** — a webhook hint (model and id only, HMAC
  signed) and a `write_date` polling sweep. Either alone suffices, both are
  idempotent, so "did the webhook fire?" is never a question anyone has to ask.
* **Deletes are never propagated as deletes.** Odoo `unlink` becomes our
  `deleted_at`; our soft delete becomes Odoo `active=False`. This is what
  prevents the classic "the sync deleted a year of accounting data" incident.
* **Nightly reconciliation** compares checksums of owned fields, auto-heals the
  safe classes, and reports the rest on the director's dashboard as a sync badge.

## Consequences

* Drift **will** still occur. The goal is detection within 24 hours and repair
  with a button, not perfection — planning for perfection is how teams end up
  with no detection at all.
* An Odoo outage is normal operation, not an incident: the circuit breaker opens,
  outbox rows accumulate, and the user sees "invoice will be issued shortly"
  rather than an error. Zero manual intervention after an outage is an acceptance
  criterion with a test behind it.
