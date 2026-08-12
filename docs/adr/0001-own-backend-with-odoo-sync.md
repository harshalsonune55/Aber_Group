# ADR 0001 — Own backend that syncs with Odoo, rather than building on Odoo

**Status:** Superseded by [ADR 0006](0006-standalone-platform-no-odoo.md) ·
**Date:** 2026-08-09

> Kept for the reasoning, which still holds where it concerns owning the
> real-estate domain. What changed is the other half: Odoo is no longer the
> system of record for accounting and payroll, because there is no Odoo. The
> option this ADR labels "3. Our own backend now, Odoo integration deferred"
> is closest to where the project actually went.

## Context

Aber Group wants an internal management platform covering HR, properties, CRM
and commissions, with full transparency for the managing director, and they want
Odoo connected to it. There were three viable shapes:

1. Odoo as the backend — our app is a custom front-end over Odoo's API.
2. Our own backend owning the real-estate domain, synced with Odoo.
3. Our own backend now, Odoo integration deferred.

## Decision

**Option 2.** Our Postgres is the system of record for the real-estate domain:
properties, leads, deals, commissions, attendance, GPS, documents. Odoo is the
system of record for accounting, payroll, and partners-as-financial-entities.

## Consequences

**We accept:**

* Two systems that must be kept consistent — the central risk of this project,
  addressed in ADR 0004 and the sync design.
* More initial work than putting everything in Odoo.

**We gain:**

* Freedom in the data model where the business is actually differentiated:
  GPS-verified attendance, viewing proof-of-visit, unit-level property tracking,
  and a commission engine with immutable, explainable runs. Odoo's models fight
  all four.
* An offline-first mobile client. Odoo's API was not designed for a mutation
  queue reconciling after hours offline; our API is designed for exactly that.
* An audit log we control end to end, which is what makes the director-
  transparency guarantee credible. Odoo's logging cannot be made tamper-evident
  without more work than building our own.
* Insulation from Odoo upgrades. All Odoo knowledge lives behind an
  anti-corruption layer in `integrations/odoo/`.

**Rejected — Odoo as backend:** fastest to a demo, but every subsequent feature
is a negotiation with Odoo's assumptions, and the offline and audit requirements
(the two things the client actually asked for) are the hardest things to retrofit.

**Rejected — defer Odoo:** the integration risk would move to the end of the
project, where it is most expensive to discover. See ADR 0004.
