.DEFAULT_GOAL := help
SHELL := /bin/bash

API_DIR   := apps/api
APP_DIR   := apps/app
VENV      := $(API_DIR)/.venv
PY        := $(VENV)/bin/python
PYTEST    := $(VENV)/bin/pytest
ALEMBIC   := $(VENV)/bin/alembic
RUFF      := $(VENV)/bin/ruff
MYPY      := $(VENV)/bin/mypy

ANDROID_HOME ?= $(HOME)/Library/Android/sdk

COMPOSE     := docker compose
COMPOSE_DEV := $(COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml

TEST_DB_URL ?= postgresql+psycopg://aber:aber@localhost:5432/aber_test

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ----------------------------------------------------------------- setup
.PHONY: bootstrap
bootstrap: ## One-command setup for a new engineer
	python3 -m venv $(VENV)
	$(PY) -m pip install --upgrade pip
	$(PY) -m pip install -e "$(API_DIR)[dev]"
	[ -f $(API_DIR)/.env ] || cp .env.example $(API_DIR)/.env
	cd $(APP_DIR) && flutter pub get
	@echo ""
	@echo "Ready. Next: make db-create && make migrate && make dev"

.PHONY: db-create
db-create: ## Create the local aber and aber_test databases
	@psql -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='aber'" | grep -q 1 \
	  || psql -d postgres -c "CREATE ROLE aber LOGIN PASSWORD 'aber'"
	@psql -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='aber'" | grep -q 1 \
	  || psql -d postgres -c "CREATE DATABASE aber OWNER aber"
	@psql -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='aber_test'" | grep -q 1 \
	  || psql -d postgres -c "CREATE DATABASE aber_test OWNER aber"
	@echo "databases ready"

.PHONY: db-drop
db-drop: ## Drop the local databases (destructive)
	psql -d postgres -c "DROP DATABASE IF EXISTS aber"
	psql -d postgres -c "DROP DATABASE IF EXISTS aber_test"

# ----------------------------------------------------------------- run
# Import the package from src rather than trusting the editable install. pip's
# generated .pth in site-packages is written without a trailing newline, which
# `site` silently skips — presenting as "No module named 'aber'" on a machine
# that worked an hour earlier. Setting this makes local runs deterministic.
# Docker installs the package normally and needs none of this.
export PYTHONPATH := $(CURDIR)/$(API_DIR)/src

.PHONY: dev
dev: ## Run the API locally with hot reload
	cd $(API_DIR) && .venv/bin/uvicorn aber.main:app --reload --host 0.0.0.0 --port 8000

.PHONY: worker
worker: ## Run a Celery worker locally
	cd $(API_DIR) && .venv/bin/celery -A aber.workers.celery_app:celery_app worker \
	  --loglevel=info --concurrency=2 --queues=default,notify,reports

.PHONY: beat
beat: ## Run Celery beat locally
	cd $(API_DIR) && .venv/bin/celery -A aber.workers.celery_app:celery_app beat \
	  --loglevel=info --scheduler=redbeat.RedBeatScheduler

# ----------------------------------------------------------------- migrations
.PHONY: migrate
migrate: ## Apply migrations to the local database
	cd $(API_DIR) && .venv/bin/alembic upgrade head

.PHONY: migration
migration: ## Draft a migration: make migration m="add employees"
	@[ -n "$(m)" ] || (echo "usage: make migration m=\"describe the change\"" && exit 1)
	cd $(API_DIR) && .venv/bin/alembic revision --autogenerate -m "$(m)"
	@echo ""
	@echo "Autogenerate output is a DRAFT. Read it before committing —"
	@echo "it does not know about RLS policies, triggers or data backfills."

.PHONY: downgrade
downgrade: ## Roll back one migration
	cd $(API_DIR) && .venv/bin/alembic downgrade -1

# ----------------------------------------------------------------- quality
.PHONY: test
test: ## Unit tests (no external dependencies)
	cd $(API_DIR) && .venv/bin/pytest tests/unit

.PHONY: test-integration
test-integration: db-create ## Integration tests against local Postgres
	cd $(API_DIR) && ABER_TEST_DATABASE_URL="$(TEST_DB_URL)" .venv/bin/pytest tests/integration

.PHONY: test-all
test-all: test test-integration ## Unit and integration tests

.PHONY: lint
lint: ## ruff + mypy
	cd $(API_DIR) && .venv/bin/ruff check src tests
	cd $(API_DIR) && .venv/bin/ruff format --check src tests
	cd $(API_DIR) && .venv/bin/mypy src

.PHONY: fmt
fmt: ## Auto-format and auto-fix
	cd $(API_DIR) && .venv/bin/ruff check --fix src tests
	cd $(API_DIR) && .venv/bin/ruff format src tests

.PHONY: verify-audit
verify-audit: ## Recompute the audit hash chain and validate anchors
	cd $(API_DIR) && .venv/bin/python scripts/verify_audit_chain.py

# ----------------------------------------------------------------- flutter
.PHONY: app-deps
app-deps: ## Fetch Flutter packages
	cd $(APP_DIR) && flutter pub get

.PHONY: app-analyze
app-analyze: ## Static analysis of the Flutter app
	cd $(APP_DIR) && flutter analyze

.PHONY: app-test
app-test: ## Flutter unit and widget tests (no backend needed)
	cd $(APP_DIR) && flutter test --exclude-tags live

.PHONY: app-macos app-android app-ios app-windows app-linux
app-macos: ## Run the app on macOS
	cd $(APP_DIR) && flutter run -d macos
app-android: ## Run the app on Android
	cd $(APP_DIR) && flutter run -d android
app-ios: ## Run the app on iOS
	cd $(APP_DIR) && flutter run -d ios
app-windows: ## Run the app on Windows
	cd $(APP_DIR) && flutter run -d windows
app-linux: ## Run the app on Linux
	cd $(APP_DIR) && flutter run -d linux

# The Mac's address on the local network. A physical phone cannot reach
# "localhost" or the emulator alias 10.0.2.2 — it needs this.
LAN_IP ?= $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
PHONE_API_URL ?= http://$(LAN_IP):8000

# The deployed backend. Override for a different environment:
#   make apk-hosted API_URL=https://staging.example.com
API_URL ?= https://aber-api.onrender.com

.PHONY: app-test-live
app-test-live: ## Flutter tests against the hosted backend
	cd $(APP_DIR) && flutter test --tags live \
	  --dart-define=ABER_API_BASE_URL=$(API_URL)

.PHONY: apk-hosted
apk-hosted: ## Build a release APK pointed at the hosted backend
	@echo "Building release APK against $(API_URL)"
	cd $(APP_DIR) && flutter build apk --release \
	  --dart-define=ABER_API_BASE_URL=$(API_URL) \
	  --dart-define=ABER_ENV=staging
	@echo ""
	@echo "APK: $(CURDIR)/$(APP_DIR)/build/app/outputs/flutter-apk/app-release.apk"

.PHONY: apk
apk: ## Build a debug APK for a physical phone, pointed at this Mac
	@[ -n "$(LAN_IP)" ] || (echo "Could not detect a LAN IP — are you on wifi?" && exit 1)
	@echo "Building APK pointed at $(PHONE_API_URL)"
	cd $(APP_DIR) && flutter build apk --debug \
	  --dart-define=ABER_API_BASE_URL=$(PHONE_API_URL)
	@echo ""
	@echo "APK: $(APP_DIR)/build/app/outputs/flutter-apk/app-debug.apk"
	@echo "Install with: make apk-install   (phone connected via USB)"

.PHONY: apk-install
apk-install: ## Install the built APK onto a USB-connected phone
	@$(ANDROID_HOME)/platform-tools/adb devices
	$(ANDROID_HOME)/platform-tools/adb install -r \
	  $(APP_DIR)/build/app/outputs/flutter-apk/app-debug.apk

.PHONY: phone-run
phone-run: ## Run with hot reload on a USB-connected phone
	@[ -n "$(LAN_IP)" ] || (echo "Could not detect a LAN IP — are you on wifi?" && exit 1)
	cd $(APP_DIR) && flutter run \
	  --dart-define=ABER_API_BASE_URL=$(PHONE_API_URL)

.PHONY: devices
devices: ## List connected phones and emulators
	@$(ANDROID_HOME)/platform-tools/adb devices -l
	cd $(APP_DIR) && flutter devices

.PHONY: api-client
api-client: ## Regenerate the Dart API client from the OpenAPI schema
	cd $(API_DIR) && .venv/bin/python scripts/export_openapi.py > ../../packages/api_client/openapi.json
	@echo "openapi.json refreshed — run the dart generator to rebuild the client"

# ----------------------------------------------------------------- docker
.PHONY: up down logs ps
up: ## Start the dockerised stack (dev overlay)
	$(COMPOSE_DEV) up -d
	$(COMPOSE_DEV) run --rm migrate
down: ## Stop the stack
	$(COMPOSE_DEV) down
logs: ## Tail logs
	$(COMPOSE_DEV) logs -f --tail=100
ps: ## Show running services
	$(COMPOSE_DEV) ps

.PHONY: seed
seed: ## Load demo data
	cd $(API_DIR) && .venv/bin/python scripts/seed_dev.py

.PHONY: clean
clean: ## Remove build and cache artefacts
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .mypy_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +
