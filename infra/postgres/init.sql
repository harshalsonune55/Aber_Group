-- Runs once, on first container start, before Alembic.
--
-- Its job is to create the least-privileged application role. The API connects
-- as aber_app, which has BYPASSRLS off, so the row-level-security policies added
-- in M8 genuinely apply to it — an SQL injection or a forgotten WHERE clause
-- still cannot read another agent's commissions or an employee's salary.
--
-- The owner role (aber) is used only by migrations.

\set app_password `echo "${APP_DB_PASSWORD:-aber_app}"`

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aber_app') THEN
        CREATE ROLE aber_app LOGIN PASSWORD 'aber_app' NOBYPASSRLS;
    END IF;
END
$$;

GRANT CONNECT ON DATABASE aber TO aber_app;
GRANT USAGE ON SCHEMA public TO aber_app;

-- Tables created later by Alembic inherit these defaults, so no grant step is
-- needed after each migration.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO aber_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO aber_app;

-- The audit schema is the exception: INSERT and SELECT only. The append-only
-- trigger from migration 0001 is the second lock; this grant is the first.
-- Revoking UPDATE/DELETE here means even a compromised application role cannot
-- rewrite history, which is what makes the director-transparency claim credible.
CREATE SCHEMA IF NOT EXISTS audit;
GRANT USAGE ON SCHEMA audit TO aber_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
    GRANT SELECT, INSERT ON TABLES TO aber_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
    REVOKE UPDATE, DELETE, TRUNCATE ON TABLES FROM aber_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
    GRANT USAGE, SELECT ON SEQUENCES TO aber_app;
