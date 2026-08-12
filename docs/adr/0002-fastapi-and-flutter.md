# ADR 0002 — FastAPI backend, Flutter client

**Status:** Accepted · **Amended** by [ADR 0006](0006-standalone-platform-no-odoo.md), which voids the Odoo-addon argument below. The decision stands on its remaining reasons · **Date:** 2026-08-09

## Context

We need one client codebase for Android, iOS and desktop (the director, HR and
finance work on laptops; agents work on phones), and a backend that also has to
carry custom Odoo addons.

## Decision

**Backend: Python 3.12 + FastAPI.** **Client: Flutter, five targets from one
codebase.**

## Rationale

### Why FastAPI

The deciding argument is that **we must write Odoo addons anyway, and they are
Python.** One language across the backend and the addons means one toolchain,
one set of linters, shared test fixtures, and the same engineer able to debug
both sides of a sync bug — which is where the hard bugs will be.

Secondary: Pydantic v2 emits an OpenAPI schema good enough to generate the Dart
client, removing a whole class of contract drift across a five-platform client;
Python and Odoo skills are abundant in the region, and any Odoo consultancy we
later engage is Python-only.

*Rejected — NestJS/TypeScript:* the shared-types argument does not apply, because
our client is Dart. It would also force a second language for the addons.
*Rejected — Django/DRF:* the admin panel is a genuine draw, but it tempts people
into writing to the database outside the service layer, which silently bypasses
the audit log — the one thing that must never be bypassed.
*Rejected — Go:* best operational story, worst Odoo-addon story.

### Why Flutter

Genuine native desktop builds for Windows, macOS and Linux from the same source
as the mobile apps. React Native's desktop story is, in practice, a second
codebase; Electron would ship a browser to render a form. Flutter also has the
strongest offline story for data-heavy business apps, and offline is structural
here rather than a nice-to-have.

The cost is that Dart is a separate language from the backend. We accept it: the
client/server boundary is a generated API client either way, so there was no type
sharing to lose.

## Consequences

* Engineers need both Python and Dart. Mitigated by strict layering — most work
  is in one or the other, rarely both at once.
* The generated `packages/api_client` is never hand-edited; CI fails if
  regenerating it produces a diff.
