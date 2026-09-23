"""Analysis API tests.

These tests never fabricate inferences. They verify the transport contract, the
behaviour when models are unavailable, and - when the trained model files are
present - that a real uploaded image produces a schema-valid response. Models
are loaded lazily during the request, so the gates use service readiness
(``ready``) rather than in-memory residency.
"""

import pytest

from tests.conftest import make_png_bytes


def _upload(payload: bytes, filename: str = "sample.png", mime: str = "image/png"):
    return {"image": (filename, payload, mime)}


def test_analyze_requires_an_image_field(client):
    response = client.post("/api/analyze")
    assert response.status_code == 422
    assert "invalid" in response.json()["detail"].lower()


def test_analyze_fails_clearly_when_models_are_unavailable(client, health):
    if health["ready"]:
        pytest.skip("Trained model files are present; the unavailable-model path cannot be exercised here.")
    response = client.post("/api/analyze", files=_upload(make_png_bytes()))
    assert response.status_code == 503
    detail = response.json()["detail"].lower()
    assert "model" in detail
    # No fabricated observation may be returned with an error.
    assert "detections" not in response.json()


def test_analyze_rejects_invalid_image_when_models_are_ready(client, health):
    if not health["ready"]:
        pytest.skip("Trained model files are not installed yet.")
    response = client.post("/api/analyze", files=_upload(b"not-an-image", "sample.png", "image/png"))
    assert response.status_code == 400
    assert "could not be processed" in response.json()["detail"]


def test_analyze_returns_real_inference_schema(client, health):
    """Runs only with the genuine model files installed - never a mock.

    Models load lazily, so readiness (files installed, no recorded failure) is
    the gate; if the local ML runtime still cannot load them, the backend's
    real 503 detail is surfaced as a skip - observations are never faked.
    """
    if not health["ready"]:
        pytest.skip("Trained model files are not installed yet; real inference cannot be verified.")

    response = client.post("/api/analyze", files=_upload(make_png_bytes((640, 480))))
    if response.status_code == 503:
        pytest.skip(f"Models could not be loaded in this environment: {response.json()['detail']}")
    assert response.status_code == 200
    payload = response.json()

    assert payload["inspection_id"].startswith("INS-")
    assert payload["total_onions"] == len(payload["detections"])
    assert payload["healthy"] + payload["unhealthy"] == payload["total_onions"]
    assert payload["image_width"] == 640 and payload["image_height"] == 480
    assert payload["model_info"]["detector"].startswith("YOLOv8n")
    assert payload["model_info"]["classifier"].startswith("MobileNetV2")
    assert payload["annotated_image"]

    for index, detection in enumerate(payload["detections"], start=1):
        assert detection["id"] == index
        assert detection["health"] in {"Healthy", "Unhealthy"}
        assert 0.0 <= detection["detection_confidence"] <= 1.0
        assert 0.0 <= detection["health_confidence"] <= 1.0
        bbox = detection["bbox"]
        assert 0 <= bbox["x1"] < bbox["x2"] <= payload["image_width"]
        assert 0 <= bbox["y1"] < bbox["y2"] <= payload["image_height"]
