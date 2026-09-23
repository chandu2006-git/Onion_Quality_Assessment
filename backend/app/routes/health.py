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
from app.services.model_registry import classifier, detector

router = APIRouter(tags=["system"])


@router.get("/health", response_model=HealthCheckResponse)
def health() -> HealthCheckResponse:
    detector_loaded = detector.loaded
    classifier_loaded = classifier.loaded
    detector_file_present = settings.detector_path.is_file()
    classifier_file_present = settings.classifier_path.is_file()
    # Readiness = trained files installed AND no load failure recorded so far.
    # A successful later load clears the recorded error again.
    ready = (
        detector_file_present
        and classifier_file_present
        and detector.load_error is None
        and classifier.load_error is None
    )
    return HealthCheckResponse(
        status="ok" if ready else "degraded",
        ready=ready,
        detector_loaded=detector_loaded,
        classifier_loaded=classifier_loaded,
        detector_error=None if detector_loaded else detector.load_error,
        classifier_error=None if classifier_loaded else classifier.load_error,
        detector_file_present=detector_file_present,
        classifier_file_present=classifier_file_present,
        version=settings.API_VERSION,
    )


@router.get("/models", tags=["system"])
def models() -> dict:
    """Technical details of the loaded models (used by the About page)."""
    return {
        "detector": {
            "architecture": detector.backend,
            "file_name": settings.detector_path.name,
            "loaded": detector.loaded,
            "classes": detector.class_names,
            "error": detector.load_error,
        },
        "classifier": {
            "architecture": classifier.backend,
            "file_name": settings.classifier_path.name,
            "loaded": classifier.loaded,
            "input_size": classifier.input_size,
            "activation": classifier.activation,
            "output_units": classifier.output_units,
            "class_names": classifier.class_names,
            "error": classifier.load_error,
        },
        "confidence_threshold": settings.CONFIDENCE_THRESHOLD,
        "max_upload_size_mb": settings.MAX_UPLOAD_SIZE_MB,
    }
