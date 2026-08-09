# ADR 0005 — Tamper-evident audit log; English UI built RTL-safe

**Status:** Accepted · **Date:** 2026-08-09

## Context

The client's stated core requirement is transparency to the managing director:
who changed what, when, and whether the record can be trusted. Separately, Aber
Group operates in the UAE, where an Arabic interface is a plausible near-term
request.

## Decision A — the audit log is tamper-evident, and nobody can edit it

* A separate Postgres schema `audit`. The application role is granted `INSERT`
  and `SELECT` only; `UPDATE`, `DELETE` and `TRUNCATE` are revoked. A
  `BEFORE UPDATE OR DELETE` trigger raises unconditionally as a second lock.
  *(Both are already in migration 0001 and asserted by integration tests.)*
* A **hash chain**: each entry stores `prev_hash` and
  `entry_hash = SHA256(prev_hash ‖ canonical_json(...))`, serialised through an
  advisory lock so the chain cannot fork. Canonical JSON is sorted-key and
  whitespace-free — pinned here because an unstated serialisation detail is what
  silently breaks chain verification two years later.
* **Daily Ed25519-signed Merkle anchors**, with the private key in deploy secrets
  and never in the database. A full database compromise still cannot rewrite
  history without invalidating a signature the director already holds.
* `GET /director/audit/verify` returns
  `{verified_through_seq, anchors_ok, first_broken_seq}` — the director presses a
  button and sees whether history is intact.

Two separations of duties make the transparency claim credible rather than
decorative: **`admin` cannot read salaries or commissions**, and **nobody,
including the director, can delete an audit entry.** The director gets a
read-everything role, not a superuser role.

Sensitive values are stored in the log as hashes, so the audit trail does not
become a second, less-guarded copy of everyone's passport numbers.

## Decision B — ship English, build RTL-safe

The V1 UI is English. Every screen is nonetheless built right-to-left-safe from
the first commit: directional insets (`EdgeInsetsDirectional`, `start`/`end`
rather than `left`/`right`), no hardcoded text direction, externalised strings.

The cost now is near zero — it is a habit, not a feature. The cost later is
revisiting every screen. Adding Arabic becomes a translation job plus a golden-
test pass, rather than a re-layout.

## Consequences

* Every write goes through the service layer. Direct database writes are a bug,
  because they bypass the log — which is also why no admin panel that writes
  outside the service layer will be added (see ADR 0002).
* Reads of sensitive resources are logged too: opening a passport scan, viewing a
  salary, exporting commissions, and each of the director's own drill-throughs.
* Audit entries are never deleted, so retention policy applies to their content
  (hashed) rather than their existence.
