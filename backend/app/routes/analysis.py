"""Inspection endpoints: real inference only.

``POST /api/analyze`` returns observations produced by the loaded YOLOv8n and
MobileNetV2 models. If a model is unavailable the endpoint fails with an explicit
error - it never substitutes mock or placeholder observations.
"""

import base64
import logging
import time

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.config import settings
from app.schemas.analysis import AnalysisResponse, Detection
from app.services.model_registry import classifier, detector
from app.services.pipeline import InspectionPipeline
from app.utils.image_utils import ImageValidationError
from app.utils.validation import validate_upload

logger = logging.getLogger(__name__)

router = APIRouter(tags=["inspection"])

MODEL_UNAVAILABLE_MESSAGE = (
    "The inspection model is not available. Please verify the configured model files."
)


def _model_metadata() -> dict:
    return {
        "detector": f"{detector.backend} ({settings.detector_path.name})",
        "classifier": f"{classifier.backend} ({settings.classifier_path.name})",
    }


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze(image: UploadFile = File(...)) -> AnalysisResponse:
    """Run the full detection + per-bulb classification pipeline."""
    started = time.perf_counter()

    if not detector.loaded or not classifier.loaded:
        logger.error(
            "Rejecting analysis request: detector_loaded=%s classifier_loaded=%s",
            detector.loaded,
            classifier.loaded,
        )
        raise HTTPException(status_code=503, detail=MODEL_UNAVAILABLE_MESSAGE)

    data = await image.read()
    try:
        pil_image = validate_upload(image.filename, image.content_type, data)
    except ImageValidationError as exc:
        logger.warning("Rejected upload %r: %s", image.filename, exc)
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    pipeline = InspectionPipeline(detector, classifier)
    try:
        result = pipeline.run(pil_image)
    except RuntimeError as exc:
        logger.error("Inference failed: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception:
        logger.exception("Unexpected error while running the inspection pipeline")
        raise HTTPException(
            status_code=500,
            detail="The inspection could not be completed. Please try again or contact the system administrator.",
        )

    response = AnalysisResponse(
        inspection_id=result["inspection_id"],
        total_onions=result["total_onions"],
        healthy=result["healthy"],
        unhealthy=result["unhealthy"],
        total_detected=result["total_onions"],
        healthy_count=result["healthy"],
        unhealthy_count=result["unhealthy"],
        detections=[Detection(**detection) for detection in result["detections"]],
        annotated_image=base64.b64encode(result["annotated_image"]).decode("ascii"),
        annotated_width=result.get("annotated_width", result["image_width"]),
        annotated_height=result.get("annotated_height", result["image_height"]),
        image_width=result["image_width"],
        image_height=result["image_height"],
        model_info=_model_metadata(),
    )
    logger.info(
        "Inspection %s complete: %s bulb(s) in %.2fs",
        response.inspection_id,
        response.total_onions,
        time.perf_counter() - started,
    )
    return response
