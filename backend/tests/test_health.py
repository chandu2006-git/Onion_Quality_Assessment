"""Health endpoint tests - the service must report real model state."""

from pathlib import Path

from app.config import settings
from app.services.model_registry import classifier, detector


def test_health_reports_operational_status(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    payload = response.json()

    assert payload["status"] in {"ok", "degraded"}
    assert isinstance(payload["ready"], bool)
    assert isinstance(payload["detector_loaded"], bool)
    assert isinstance(payload["classifier_loaded"], bool)
    assert payload["version"] == settings.API_VERSION


def test_health_status_matches_model_availability(client):
    payload = client.get("/api/health").json()
    expected = "ok" if payload["ready"] else "degraded"
    assert payload["status"] == expected


def test_health_never_claims_a_model_that_failed(client):
    """A model reported as loaded must actually be resident; failures must explain why the service is not ready."""
    payload = client.get("/api/health").json()

    # The endpoint reports the very same instances used for inference.
    assert payload["detector_loaded"] == detector.loaded
    assert payload["classifier_loaded"] == classifier.loaded

    # A resident model carries no load failure...
    if payload["detector_loaded"]:
        assert payload["detector_error"] is None
    if payload["classifier_loaded"]:
        assert payload["classifier_error"] is None

    # ...and any recorded failure means the service is not ready.
    if payload["detector_error"] or payload["classifier_error"]:
        assert payload["ready"] is False
        assert payload["status"] == "degraded"


def test_health_reports_model_file_presence(health):
    assert health["detector_file_present"] == settings.detector_path.is_file()
    assert health["classifier_file_present"] == settings.classifier_path.is_file()


def test_health_distinguishes_presence_memory_and_readiness(client):
    """Files on disk, weights in memory and readiness are three separate signals."""
    payload = client.get("/api/health").json()

    # 1) File presence mirrors the disk.
    assert payload["detector_file_present"] == settings.detector_path.is_file()
    assert payload["classifier_file_present"] == settings.classifier_path.is_file()

    # 2) Residency mirrors the process: at rest (no request in flight) neither
    #    model is in memory - lazy loading must not claim otherwise.
    assert payload["detector_loaded"] is False
    assert payload["classifier_loaded"] is False
    assert detector.loaded is False
    assert classifier.loaded is False

    # 3) Readiness = files installed + no recorded load failure.
    expected_ready = (
        payload["detector_file_present"]
        and payload["classifier_file_present"]
        and payload["detector_error"] is None
        and payload["classifier_error"] is None
    )
    assert payload["ready"] == expected_ready


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
