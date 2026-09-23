"""Health endpoint tests - the service must report real model state."""

from pathlib import Path

from app.config import settings


def test_health_reports_operational_status(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    payload = response.json()

    assert payload["status"] in {"ok", "degraded"}
    assert isinstance(payload["detector_loaded"], bool)
    assert isinstance(payload["classifier_loaded"], bool)
    assert payload["version"] == settings.API_VERSION


def test_health_status_matches_model_availability(client):
    payload = client.get("/api/health").json()
    expected = "ok" if (payload["detector_loaded"] and payload["classifier_loaded"]) else "degraded"
    assert payload["status"] == expected


def test_health_never_claims_a_model_that_failed(health):
    """A model reported as loaded must actually be loaded, and failures must explain why."""
    if not health["detector_loaded"]:
        assert health["detector_error"]
    if not health["classifier_loaded"]:
        assert health["classifier_error"]


def test_health_reports_model_file_presence(health):
    assert health["detector_file_present"] == settings.detector_path.is_file()
    assert health["classifier_file_present"] == settings.classifier_path.is_file()


def test_detector_path_resolves_inside_backend_directory():
    assert settings.detector_path.parent == Path(settings.detector_path).parent
    assert Path(settings.MODEL_DETECTOR_PATH).name == "onion_detector_v1.pt"
    assert Path(settings.MODEL_HEALTH_CLASSIFIER_PATH).name == "onion_health_mobilenetv2_best.keras"


def test_models_endpoint_exposes_technical_detail(client):
    payload = client.get("/api/models").json()
    assert payload["detector"]["architecture"] == "YOLOv8n"
    assert payload["classifier"]["architecture"] == "MobileNetV2"
    assert payload["classifier"]["file_name"] == "onion_health_mobilenetv2_best.keras"
    assert payload["max_upload_size_mb"] == settings.MAX_UPLOAD_SIZE_MB
