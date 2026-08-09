# ADR 0003 — Riverpod, and client-generated UUIDv7 for offline writes

**Status:** Accepted · **Date:** 2026-08-09

## Context

Agents work at properties with poor or no signal. They must be able to check in,
log a viewing, photograph a unit and update a lead while offline, then have all
of it reconcile when they get back into coverage. This is not a degraded mode —
it is the normal working day.

## Decision

1. **Riverpod** for state management.
2. **The client generates UUIDv7 primary keys**, and the server accepts them.
3. Every mutating request carries an **`Idempotency-Key`**.

## Rationale

### Riverpod over BLoC

Async caching, invalidation and dependency composition are first-class, which is
precisely the shape of an offline-first app: stream from the local database,
refresh from the network, invalidate on sync. Compile-safe dependency injection
means tests override real dependencies with fakes without a service locator.
BLoC's event sourcing adds ceremony that buys little across ten feature modules.

### Client-generated UUIDv7 — the important one

The alternative is server-assigned ids with client temp-ids rewritten on sync.
That approach requires rewriting every foreign key referencing a temp id, and it
fails in exactly the cases that matter: a lead created offline, with a viewing
attached to it, with photos attached to the viewing, all before any of it has
been near a server.

Letting the client mint the real id removes that entire class of bug. UUIDv7
rather than v4 because the leading 48 bits are a timestamp, so index locality on
insert stays close to a sequential key's.

### Idempotency keys

A dropped connection mid-request is indistinguishable, from the client, from a
failure. Without an idempotency key the safe behaviour is to not retry, and the
agent loses work; with one, the retry is free. The server caches the response
against the key for 7 days and replays it. Offline-created entities additionally
carry `client_mutation_id UNIQUE`, so the protection is structural — a duplicate
is rejected by a database constraint even if the caching layer misbehaves.

## Consequences

* The server must never assume it assigns ids. Enforced by tests.
* Id collision is a theoretical concern only: 74 random bits per millisecond.
* Conflict handling is still needed for *concurrent edits* — idempotency solves
  duplicate submission, not two people changing the same field. That is the
  per-entity conflict policy, which lands with the sync engine in M3.
