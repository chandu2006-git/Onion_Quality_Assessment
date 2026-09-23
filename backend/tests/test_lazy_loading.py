"""Lazy / sequential model loading guarantees (512 MiB deployment budget).

These tests verify the memory architecture around the REAL trained models -
they never fabricate inference:

* the server starts without loading either model;
* at rest neither model is resident in memory;
* an analysis loads YOLOv8n, releases it, then loads MobileNetV2 and releases
  it - both models are never resident at the same time;
* the process-wide inference lock serialises the sequence and is always
  released, even when a load fails.

The order tests wrap the real ``load``/``unload``/``detect``/``classify``
methods only to RECORD call order and residency; every model call itself is
the genuine one.
"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.main import app
from app.services.classifier import OnionHealthClassifier
from app.services.model_registry import classifier, detector, inference_lock
from tests.conftest import make_png_bytes

MISSING_CLASSIFIER = "definitely_missing_model_for_tests.keras"


def _upload(payload: bytes, filename: str = "sample.png", mime: str = "image/png"):
    return {"image": (filename, payload, mime)}


def test_startup_does_not_load_any_model():
    """The server must start successfully without loading either ML model."""
    with TestClient(app) as startup_client:
        payload = startup_client.get("/api/health").json()

    assert payload["detector_loaded"] is False
    assert payload["classifier_loaded"] is False
    assert detector.loaded is False
    assert classifier.loaded is False
    # File presence is still reported honestly at startup.
    assert payload["detector_file_present"] == settings.detector_path.is_file()
    assert payload["classifier_file_present"] == settings.classifier_path.is_file()


def test_models_are_not_resident_at_rest(client):
    """Between requests both models must be out of memory."""
    payload = client.get("/api/health").json()

    assert payload["detector_loaded"] is False
    assert payload["classifier_loaded"] is False
    assert detector.loaded is False
    assert classifier.loaded is False
    assert not inference_lock.locked()


def test_inference_lock_is_usable_and_released(client):
    client.get("/api/health")  # service responds normally with the lock free

    assert inference_lock.acquire(blocking=False)
    try:
        assert inference_lock.locked()
    finally:
        inference_lock.release()
    assert not inference_lock.locked()


def test_unload_methods_are_idempotent_at_rest():
    detector.unload()
    detector.unload()
    classifier.unload()
    classifier.unload()

    assert detector.loaded is False
    assert classifier.loaded is False


def test_analysis_loads_and_releases_models_sequentially(client):
    """Full real inference: YOLO loads, runs, unloads BEFORE MobileNetV2 loads."""
    health = client.get("/api/health").json()
    if not health["ready"]:
        pytest.skip("Trained model files are not installed; sequential loading cannot be exercised here.")

    events = []  # (name, det_resident_before, cls_resident_before,
    #                det_resident_after, cls_resident_after, lock_held)

    def wrap(name, real_method):
        def wrapper(*args, **kwargs):
            before = (detector.loaded, classifier.loaded, inference_lock.locked())
            result = real_method(*args, **kwargs)
            after = (detector.loaded, classifier.loaded, inference_lock.locked())
            events.append((name, *before, *after))
            return result

        return wrapper

    real = {
        ("detector", "load"): detector.load,
        ("detector", "detect"): detector.detect,
        ("detector", "unload"): detector.unload,
        ("classifier", "load"): classifier.load,
        ("classifier", "classify"): classifier.classify,
        ("classifier", "unload"): classifier.unload,
    }
    detector.load = wrap("detector.load", real[("detector", "load")])
    detector.detect = wrap("detector.detect", real[("detector", "detect")])
    detector.unload = wrap("detector.unload", real[("detector", "unload")])
    classifier.load = wrap("classifier.load", real[("classifier", "load")])
    classifier.classify = wrap("classifier.classify", real[("classifier", "classify")])
    classifier.unload = wrap("classifier.unload", real[("classifier", "unload")])

    try:
        response = client.post("/api/analyze", files=_upload(make_png_bytes((640, 480))))
        if response.status_code == 503:
            pytest.skip(f"Models could not be loaded in this environment: {response.json()['detail']}")
        assert response.status_code == 200, response.text
        payload = response.json()
    finally:
        # Always restore the real methods, even if an assertion below fails.
        for (owner, name), method in real.items():
            setattr(detector if owner == "detector" else classifier, name, method)

    names = [event[0] for event in events]

    # --- Strict lifecycle order ------------------------------------------
    assert names[0] == "detector.load"
    assert names[1] == "detector.detect"
    assert names.count("detector.detect") == 1
    assert names[2] == "detector.unload"
    assert names[3] == "classifier.load"
    assert names[-1] == "classifier.unload"
    # Detector is fully released before the classifier phase begins.
    assert names.index("detector.unload") < names.index("classifier.load")
    # Detection happens strictly between detector load/unload.
    assert names.index("detector.load") < names.index("detector.detect") < names.index("detector.unload")
    # Every classification happens strictly between classifier load/unload.
    load_index = names.index("classifier.load")
    unload_index = names.index("classifier.unload")
    for index, name in enumerate(names):
        if name == "classifier.classify":
            assert load_index < index < unload_index

    # --- Residency invariants (never both models in memory) ---------------
    for name, det_before, cls_before, lock_before, det_after, cls_after, lock_after in events:
        assert lock_before and lock_after, f"inference lock not held during {name}"
        if name == "detector.load":
            assert det_before is False and cls_before is False
            assert det_after is True and cls_after is False
        elif name == "detector.detect":
            assert det_before is True and cls_before is False
        elif name == "detector.unload":
            assert det_after is False
        elif name == "classifier.load":
            # KEY invariant: YOLO is already gone when TensorFlow loads.
            assert det_before is False and cls_before is False, "detector still resident when classifier loads"
            assert cls_after is True
        elif name == "classifier.classify":
            assert cls_before is True and det_before is False
        elif name == "classifier.unload":
            assert cls_after is False

    # Real inference ran once per non-empty detection crop.
    assert payload["total_onions"] == names.count("classifier.classify")

    # --- Released after the request --------------------------------------
    assert detector.loaded is False
    assert classifier.loaded is False
    assert not inference_lock.locked()
    after_health = client.get("/api/health").json()
    assert after_health["detector_loaded"] is False
    assert after_health["classifier_loaded"] is False


def test_classifier_failure_still_releases_detector_and_lock(client):
    """If the classifier cannot load, YOLO is already released, the lock frees,
    and /api/health reports the real failure - a 503, never fabricated data."""
    health = client.get("/api/health").json()
    if not health["ready"]:
        pytest.skip("Trained model files are not installed; the failure path cannot be exercised here.")

    events = []
    real_detector_load = detector.load
    real_detector_unload = detector.unload
    real_classifier_load = classifier.load
    real_classifier_unload = classifier.unload

    def recording_detector_load():
        events.append(("detector.load", detector.loaded, classifier.loaded))
        return real_detector_load()

    def recording_detector_unload():
        result = real_detector_unload()
        events.append(("detector.unload", detector.loaded, classifier.loaded))
        return result

    def recording_classifier_load():
        # KEY invariant: detector must already be released at this point.
        events.append(("classifier.load", detector.loaded, classifier.loaded))
        return real_classifier_load()

    def recording_classifier_unload():
        result = real_classifier_unload()
        events.append(("classifier.unload", detector.loaded, classifier.loaded))
        return result

    detector.load = recording_detector_load
    detector.unload = recording_detector_unload
    classifier.load = recording_classifier_load
    classifier.unload = recording_classifier_unload
    # Force the classifier's model-file lookup to fail (real load() code path).
    original_path = OnionHealthClassifier.model_path
    OnionHealthClassifier.model_path = property(lambda self: Path(MISSING_CLASSIFIER))

    try:
        response = client.post("/api/analyze", files=_upload(make_png_bytes()))

        assert response.status_code == 503
        detail = response.json()["detail"]
        assert MISSING_CLASSIFIER in detail
        assert "detections" not in response.json()

        # Full sequence: detector released before the classifier load attempt,
        # and its wrapper released even though loading failed.
        assert [event[0] for event in events] == [
            "detector.load",
            "detector.unload",
            "classifier.load",
            "classifier.unload",
        ]
        # At the classifier load attempt the detector was already gone.
        assert events[2][1] is False, "detector still resident when classifier load was attempted"

        # Nothing left resident; the lock was released by the context manager.
        assert detector.loaded is False
        assert classifier.loaded is False
        assert not inference_lock.locked()

        # /api/health tells the truth about the failure.
        payload = client.get("/api/health").json()
        assert payload["ready"] is False
        assert payload["status"] == "degraded"
        assert payload["detector_error"] is None
        assert payload["classifier_error"] is not None
        assert MISSING_CLASSIFIER in payload["classifier_error"]
        assert payload["detector_loaded"] is False
        assert payload["classifier_loaded"] is False
    finally:
        detector.load = real_detector_load
        detector.unload = real_detector_unload
        classifier.load = real_classifier_load
        classifier.unload = real_classifier_unload
        OnionHealthClassifier.model_path = original_path
        # Clear the deliberately induced failure so later checks see true state.
        classifier.load_error = None


