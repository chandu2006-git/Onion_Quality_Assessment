"""CORS tests: the deployed Firebase frontends must be able to reach the API.

This is the exact production failure that made real AI inference and PDF
generation look broken from the public frontend: the preflight request from
``https://mindflayers3.web.app`` was answered with HTTP 400
"Disallowed CORS origin", so the browser blocked ``/api/analyze`` and
``/api/report`` even though the Render service itself worked.
"""

import pytest

from app.config import PRODUCTION_FRONTEND_ORIGINS, settings

PREFLIGHT_HEADERS = {
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "content-type",
}


@pytest.mark.parametrize("origin", PRODUCTION_FRONTEND_ORIGINS)
def test_production_firebase_origins_pass_the_preflight(client, origin):
    response = client.options(
        "/api/analyze",
        headers={"Origin": origin, **PREFLIGHT_HEADERS},
    )
    assert response.status_code == 200, response.text
    assert response.headers["access-control-allow-origin"] == origin


def test_production_origin_is_allowed_on_health_and_report(client):
    origin = PRODUCTION_FRONTEND_ORIGINS[0]
    health = client.get("/api/health", headers={"Origin": origin})
    assert health.status_code == 200
    assert health.headers.get("access-control-allow-origin") == origin

    report = client.post("/api/report", json={}, headers={"Origin": origin})
    assert report.headers.get("access-control-allow-origin") == origin


def test_preview_channel_origin_is_allowed(client):
    origin = "https://mindflayers3--preview-abc123.web.app"
    response = client.options(
        "/api/analyze",
        headers={"Origin": origin, **PREFLIGHT_HEADERS},
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin


def test_unknown_origin_is_still_rejected(client):
    response = client.options(
        "/api/analyze",
        headers={"Origin": "https://not-our-frontend.example.com", **PREFLIGHT_HEADERS},
    )
    assert response.status_code == 400


def test_production_origins_are_merged_into_the_configured_list():
    """A minimal or stale CORS_ORIGINS value can never drop the real frontend.

    The test environment configures only ``http://localhost:8080`` (see
    conftest), which is exactly the situation that broke production: the
    configured origin is preserved AND every production frontend is appended.
    """
    origins = settings.cors_origins_list
    assert "http://localhost:8080" in origins
    for origin in PRODUCTION_FRONTEND_ORIGINS:
        assert origin in origins
