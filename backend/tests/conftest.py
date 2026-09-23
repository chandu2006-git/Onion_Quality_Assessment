"""Shared pytest fixtures.

The FastAPI application is exercised through ``TestClient`` with its real
lifespan, so startup behaves exactly as in production: no model is loaded at
startup - the weights are loaded lazily, one model at a time, during
``/api/analyze``. The tests adapt to whether the trained model files are
present instead of faking inference.
"""

import io
import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Keep test runs quiet and independent of a developer's local .env tweaks.
os.environ.setdefault("LOG_LEVEL", "WARNING")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:8080")

from app.main import app  # noqa: E402  (import after sys.path setup)


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def health(client):
    return client.get("/api/health").json()


@pytest.fixture(scope="session")
def models_ready(health) -> bool:
    """True only when the service reports ready for real inference (files
    installed and no recorded load failure)."""
    return bool(health.get("ready"))


def make_png_bytes(size=(320, 240), colour=(200, 170, 90)) -> bytes:
    """Create genuine PNG image bytes (used for upload validation tests)."""
    buffer = io.BytesIO()
    Image.new("RGB", size, colour).save(buffer, format="PNG")
    return buffer.getvalue()


@pytest.fixture
def png_bytes() -> bytes:
    return make_png_bytes()
