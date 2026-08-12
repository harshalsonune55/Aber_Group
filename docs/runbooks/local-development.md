# Runbook — local development and testing

## First-time setup

```bash
make bootstrap    # venv, Python deps, Flutter packages, .env from .env.example
make db-create    # creates the aber and aber_test databases and the aber role
make migrate      # applies the Alembic history
```

Requires PostgreSQL and Redis running locally. On macOS with Homebrew:

```bash
brew services start postgresql@14
brew services start redis
```

## Everyday loop

```bash
make dev          # API with hot reload on :8000
make worker       # Celery worker (separate terminal, only needed from M2)
make app-macos    # or app-android / app-windows / app-linux
```

## Testing

See the Testing section of the README. Short version:

```bash
make test && make test-integration && make app-test && make lint
```

## Known toolchain gaps on the current dev Mac

| Gap | Effect | Fix |
|---|---|---|
| No Docker | `make up` unavailable. Tests and the API run against a local Postgres instead; Docker is only needed for deployment. | Install Docker Desktop. |
| Command Line Tools only, no full Xcode | `flutter build macos` and `ios` fail. | Install Xcode from the App Store, then `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, then `sudo gem install cocoapods`. |
| Android SDK missing cmdline-tools | `flutter build apk` fails. | Install via Android Studio's SDK Manager, then `flutter doctor --android-licenses`. |
| Postgres 14, production targets 16 | Nothing today; check before using 15+ only syntax. | Optional: `brew install postgresql@16`. |

Until those are resolved, native builds are verified by CI
(`.github/workflows/flutter.yml`): Android on every pull request, and macOS,
Windows and Linux on pushes to `main`.

## Common problems

**`make test-integration` skips every test.** No test database. Run
`make db-create`, or set `ABER_TEST_DATABASE_URL` to a Postgres you control.

**`make app-test-live` fails with "No backend".** The hosted API or configured
`API_URL` is not reachable. For local testing, start `make dev` in another
terminal and run `make app-test-live API_URL=http://127.0.0.1:8000`.

**The Android emulator cannot reach a local API.** The emulator's `localhost` is
the emulator itself. Use the hosted default, or override explicitly with
`flutter run --dart-define=ABER_API_BASE_URL=http://10.0.2.2:8000`.

**Alembic points at the wrong database.** `migrations/env.py` uses an explicitly
supplied `sqlalchemy.url` when there is one, and otherwise falls back to
`ABER_DATABASE_URL_SYNC` from settings. Check `apps/api/.env`.
