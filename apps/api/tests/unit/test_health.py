from __future__ import annotations

from fastapi.testclient import TestClient


def test_health_reports_ok(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "aber-api"


def test_health_reflects_the_apps_own_settings(client: TestClient) -> None:
    # Guards against the endpoint reading the cached global Settings instead of
    # the instance the app was constructed with.
    assert client.get("/health").json()["environment"] == "test"


def test_request_id_is_echoed_back(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "trace-me-123"})
    assert response.headers["X-Request-ID"] == "trace-me-123"


def test_request_id_is_generated_when_absent(client: TestClient) -> None:
    assert client.get("/health").headers.get("X-Request-ID")


def test_openapi_schema_is_served(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    assert schema["info"]["title"] == "Aber Group API"
    assert "/health" in schema["paths"]
