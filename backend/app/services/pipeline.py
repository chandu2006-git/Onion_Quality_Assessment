"""Inspection pipeline: detection -> per-bulb classification -> evidence image.

All values returned by :meth:`InspectionPipeline.run` come from real inference.
No canned, cached or placeholder observations are produced anywhere in this
module.

To stay inside the 512 MiB memory limit of the free Render instance the two
models are never resident at the same time. Inside a process-wide lock the
pipeline loads YOLOv8n, runs detection, releases the detector (garbage
collected), then loads MobileNetV2, classifies the crops, and releases the
classifier again - one model in memory at any moment.
"""

import logging
import uuid
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

from app.config import settings
from app.services.classifier import HEALTHY, OnionHealthClassifier
from app.services.detector import OnionDetector
from app.services.model_registry import inference_lock
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
        original = pil_to_cv2(pil_image)
        height, width = original.shape[:2]

        # Very large uploads are downscaled for detection only; the returned
        # boxes are mapped back to original-image coordinates.
        inference_image, scale = fit_for_inference(original, settings.MAX_INFERENCE_SIDE)

        detections: List[Dict] = []
        # The whole load -> infer -> release sequence is serialised so
        # concurrent requests can never load duplicate copies of the models.
        with inference_lock:
            # --- Phase 1: YOLOv8n detection, then release it -----------------
            detector_ok = self.detector.load()
            try:
                if not detector_ok:
                    raise RuntimeError(
                        self.detector.load_error or "Detector model could not be loaded."
                    )
                candidates = self.detector.detect(inference_image)
                logger.info(
                    "Detector returned %s candidate bulb(s) for a %sx%s image (detection scale %.3f)",
                    len(candidates),
                    width,
                    height,
                    scale,
                )
                # Crop every bulb now so phase 2 needs only the classifier.
                pending: List[Tuple[Dict, float, np.ndarray]] = []
                for candidate in candidates:
                    bbox = scale_bbox(candidate["bbox"], 1.0 / scale, width, height)
                    crop = crop_bbox(original, bbox)
                    if crop.size == 0:
                        logger.warning("Skipping detection with an empty crop: %s", bbox)
                        continue
                    pending.append((bbox, candidate["detection_confidence"], crop))
            finally:
                # Drop the PyTorch weights (and garbage-collect them) BEFORE
                # TensorFlow is loaded so both models are never resident at the
                # same time (512 MiB deployment limit).
                self.detector.unload()

            # --- Phase 2: MobileNetV2 classification, then release it --------
            logger.info("CLASSIFIER PHASE: starting load")
            classifier_ok = self.classifier.load()
            logger.info("CLASSIFIER PHASE: load complete (success=%s)", classifier_ok)

            try:
                if not classifier_ok:
                    raise RuntimeError(
                        self.classifier.load_error or "Health classifier model could not be loaded."
                    )

                logger.info(
                    "CLASSIFIER PHASE: starting inference for %s crop(s)",
                    len(pending),
                )

                for bbox, confidence, crop in pending:
                    # Each detected bulb is evaluated independently by the classifier.
                    classification = self.classifier.classify(crop)
                    detections.append(
                        {
                            "id": len(detections) + 1,
                            "bbox": bbox,
                            "detection_confidence": confidence,
                            "health": classification["health"],
                            "health_confidence": classification["health_confidence"],
                        }
                    )

                logger.info("CLASSIFIER PHASE: inference complete")

            finally:
                # Release the TensorFlow weights as soon as inference is done.
                self.classifier.unload()
                logger.info("CLASSIFIER PHASE: released")

        # Evidence image needs no model and runs outside the lock.
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
