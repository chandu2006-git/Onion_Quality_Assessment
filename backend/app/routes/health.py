"""Health and readiness endpoint.

Reports three distinct signals and never conflates them:

* ``*_file_present``  - the trained model artefacts are installed on disk;
* ``*_loaded``        - weights are resident in memory *right now* (models are
  loaded lazily during analysis, so both are normally false at rest);
* ``ready`` / ``status`` - the service can serve analyses: files installed and
  no recorded load failure.

It never claims a model is loaded when it is not.
"""

from fastapi import APIRouter

from app.config import settings
from app.schemas.report import HealthCheckResponse
from app.services.diagnostics import inference
from app.services.model_registry import classifier, detector

router = APIRouter(tags=["system"])


@router.get("/health", response_model=HealthCheckResponse)
def health() -> HealthCheckResponse:
    """Report the honest, granular service and model state.

    ``loaded == false`` at rest is the documented lazy-loading behaviour and is
    NOT treated as a failure. ``analysis_available`` is false only when a model
    file is missing or a real load attempt failed, and in that case the actual
    error message is reported (never ``null``).
    """
    detector_loaded = detector.loaded
    classifier_loaded = classifier.loaded
    detector_file_present = settings.detector_path.is_file()
    classifier_file_present = settings.classifier_path.is_file()
    # Readiness = trained files installed AND no load failure recorded so far.
    # A successful later load clears the recorded error again.
    analysis_available = (
        detector_file_present
        and classifier_file_present
        and detector.load_error is None
        and classifier.load_error is None
    )
    diagnostics = inference.snapshot()
    return HealthCheckResponse(
        status="ok" if analysis_available else "degraded",
        ready=analysis_available,
        service_available=True,
        analysis_available=analysis_available,
        detector_loaded=detector_loaded,
        classifier_loaded=classifier_loaded,
        # The real recorded failure is always reported, even when the model is
        # currently released again after an earlier successful load.
        detector_error=detector.load_error,
        classifier_error=classifier.load_error,
        detector_file_present=detector_file_present,
        classifier_file_present=classifier_file_present,
        version=settings.API_VERSION,
        detector_load_attempts=detector.load_attempts,
        classifier_load_attempts=classifier.load_attempts,
        detector_last_load_ok=detector.last_load_ok,
        classifier_last_load_ok=classifier.last_load_ok,
        detector_last_load_ms=detector.last_load_ms,
        classifier_last_load_ms=classifier.last_load_ms,
        **diagnostics,
    )


@router.get("/models", tags=["system"])
def models() -> dict:
    """Technical details of the models (used by the About page).

    Separates model AVAILABILITY from in-memory RESIDENCY: because weights load
    lazily per analysis, ``loaded`` is false at rest. ``classes`` is reported
    only after the detector has genuinely been loaded, so an empty mapping is
    never mistaken for a broken model.
    """
    diagnostics = inference.snapshot()
    return {
        "service": {
            "available": True,
            "analysis_available": settings.models_present
            and detector.load_error is None
            and classifier.load_error is None,
            "lazy_loading": True,
            "model_files_present": settings.models_present,
        },
        "detector": {
            "architecture": detector.backend,
            "file_name": settings.detector_path.name,
            "file_present": settings.detector_path.is_file(),
            "loaded": detector.loaded,
            "load_attempts": detector.load_attempts,
            "last_load_ok": detector.last_load_ok,
            "last_load_ms": detector.last_load_ms,
            "classes": detector.class_names if detector.loaded else None,
            "classes_note": (
                None
                if detector.loaded
                else "Reported after the first real analysis (models load lazily)."
            ),
            "error": detector.load_error,
        },
        "classifier": {
            # The TFLite artefact is the trained MobileNetV2 model, executed by
            # the LiteRT runtime (no TensorFlow dependency at inference time).
            "architecture": "MobileNetV2",
            "runtime": classifier.backend,
            "file_name": settings.classifier_path.name,
            "file_present": settings.classifier_path.is_file(),
            "loaded": classifier.loaded,
            "load_attempts": classifier.load_attempts,
            "last_load_ok": classifier.last_load_ok,
            "last_load_ms": classifier.last_load_ms,
            "classes": ["Healthy", "Unhealthy"],
            "error": classifier.load_error,
        },
        "last_inference": diagnostics,
        "confidence_threshold": settings.CONFIDENCE_THRESHOLD,
        "max_upload_size_mb": settings.MAX_UPLOAD_SIZE_MB,
    }
