"""Inspection pipeline: detection -> per-bulb classification -> evidence image.

All values returned by :meth:`InspectionPipeline.run` come from real inference.
No canned, cached or placeholder observations are produced anywhere in this
module.
"""

import logging
import uuid
from typing import Dict, List, Optional

from PIL import Image

from app.config import settings
from app.services.classifier import HEALTHY, OnionHealthClassifier
from app.services.detector import OnionDetector
from app.utils.image_utils import (
    crop_bbox,
    cv2_to_pil,
    draw_annotations,
    encode_image_to_bytes,
    fit_for_inference,
    limit_long_side,
    pil_to_cv2,
    scale_bbox,
)

logger = logging.getLogger(__name__)


class InspectionPipeline:
    """Runs the full detection + classification pipeline for one uploaded image."""

    def __init__(self, detector: OnionDetector, classifier: OnionHealthClassifier) -> None:
        self.detector = detector
        self.classifier = classifier

    def run(self, pil_image: Image.Image, inspection_id: Optional[str] = None) -> Dict:
        if not self.detector.loaded:
            raise RuntimeError(self.detector.load_error or "Detector model is not loaded.")
        if not self.classifier.loaded:
            raise RuntimeError(self.classifier.load_error or "Health classifier model is not loaded.")

        original = pil_to_cv2(pil_image)
        height, width = original.shape[:2]

        # Very large uploads are downscaled for detection only; the returned
        # boxes are mapped back to original-image coordinates.
        inference_image, scale = fit_for_inference(original, settings.MAX_INFERENCE_SIDE)
        candidates = self.detector.detect(inference_image)
        logger.info(
            "Detector returned %s candidate bulb(s) for a %sx%s image (detection scale %.3f)",
            len(candidates),
            width,
            height,
            scale,
        )

        detections: List[Dict] = []
        for candidate in candidates:
            bbox = scale_bbox(candidate["bbox"], 1.0 / scale, width, height)
            crop = crop_bbox(original, bbox)
            if crop.size == 0:
                logger.warning("Skipping detection with an empty crop: %s", bbox)
                continue
            # Each detected bulb is evaluated independently by the classifier.
            classification = self.classifier.classify(crop)
            detections.append(
                {
                    "id": len(detections) + 1,
                    "bbox": bbox,
                    "detection_confidence": candidate["detection_confidence"],
                    "health": classification["health"],
                    "health_confidence": classification["health_confidence"],
                }
            )

        annotated = draw_annotations(original, detections)
        evidence = limit_long_side(cv2_to_pil(annotated), settings.EVIDENCE_IMAGE_MAX_SIDE)
        annotated_bytes = encode_image_to_bytes(
            evidence,
            "JPEG",
            quality=settings.ANNOTATED_IMAGE_QUALITY,
        )

        healthy = sum(1 for detection in detections if detection["health"] == HEALTHY)
        return {
            "inspection_id": inspection_id or f"INS-{uuid.uuid4().hex[:8].upper()}",
            "total_onions": len(detections),
            "healthy": healthy,
            "unhealthy": len(detections) - healthy,
            "detections": detections,
            "annotated_image": annotated_bytes,
            "annotated_width": evidence.width,
            "annotated_height": evidence.height,
            "image_width": width,
            "image_height": height,
        }
