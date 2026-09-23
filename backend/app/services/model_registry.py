"""Process-wide model instances.

The detector and the classifier are loaded once during application startup and
reused by every request. Routes import the instances from this module so that
``/api/health`` always reports the state of the very same models used for
inference - never a separate, never-loaded copy.
"""

import logging
from typing import Dict

from app.services.classifier import OnionHealthClassifier
from app.services.detector import OnionDetector

logger = logging.getLogger(__name__)

detector = OnionDetector()
classifier = OnionHealthClassifier()


def load_models() -> Dict[str, bool]:
    """Load both models. Returns the individual load results."""
    logger.info("Loading inspection models...")
    detector_ok = detector.load()
    classifier_ok = classifier.load()
    if detector_ok and classifier_ok:
        logger.info("Inspection models ready.")
    else:
        logger.error(
            "Inspection models are not fully available (detector_loaded=%s, classifier_loaded=%s). "
            "Place the trained model files in backend/models/ and restart the service.",
            detector_ok,
            classifier_ok,
        )
    return {"detector_loaded": detector_ok, "classifier_loaded": classifier_ok}


def models_ready() -> bool:
    return detector.loaded and classifier.loaded
