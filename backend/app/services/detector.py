"""YOLOv8n onion bulb detector.

The model file is expected at ``settings.detector_path``. ``ultralytics`` is
imported lazily inside :meth:`OnionDetector.load` so the API can start - and
report an accurate configuration error through ``/api/health`` - even when the
ML runtime or the trained model file is not available yet.

Weights are loaded on demand and released again via :meth:`OnionDetector.unload`
so the detector and the health classifier are never resident in memory at the
same time (512 MiB deployment limit).
"""

import gc
import logging
import time
from typing import Dict, List, Optional

import numpy as np

from app.config import settings

logger = logging.getLogger(__name__)


class OnionDetector:
    """Wrapper around the trained YOLOv8n onion detector."""

    backend = "YOLOv8n"

    def __init__(self) -> None:
        self._model = None
        self._class_names: Dict[int, str] = {}
        self.load_error: Optional[str] = None
        # --- Load/inference diagnostics (reported by /api/health) ---------
        self.load_attempts: int = 0
        self.last_load_ok: Optional[bool] = None
        self.last_load_ms: Optional[float] = None
        self.last_loaded_at: Optional[float] = None
        self.last_inference_ok: Optional[bool] = None
        self.last_inference_error: Optional[str] = None

    @property
    def loaded(self) -> bool:
        return self._model is not None

    @property
    def model_path(self):
        return settings.detector_path

    @property
    def class_names(self) -> Dict[int, str]:
        return dict(self._class_names)

    def load(self) -> bool:
        """Load the detector into memory. Returns True on success.

        Called lazily per analysis (never at application startup) and always
        paired with :meth:`unload` by the pipeline.
        """
        self._model = None
        self.load_error = None
        self._class_names = {}
        self.load_attempts += 1
        started = time.monotonic()
        path = self.model_path
        if not path.is_file():
            self.load_error = f"Detector model file not found: {path.name}"
            logger.error("Detector model file not found at %s", path)
            return self._record_load(False, started)
        try:
            from ultralytics import YOLO  # imported lazily: heavy dependency

            self._model = YOLO(str(path))
            names = getattr(self._model, "names", None)
            if isinstance(names, dict):
                self._class_names = {int(key): str(value) for key, value in names.items()}
            logger.info("Detector loaded from %s (classes: %s)", path.name, self._class_names or "not reported")
            self.last_loaded_at = time.time()
            return self._record_load(True, started)
        except Exception as exc:  # pragma: no cover - depends on local ML runtime
            self._model = None
            self.load_error = f"Detector could not be loaded: {exc}"
            logger.exception("Failed to load the detector model")
            return self._record_load(False, started)

    def _record_load(self, ok: bool, started: float) -> bool:
        """Record the real load outcome (never a guessed one)."""
        self.last_load_ok = ok
        self.last_load_ms = round((time.monotonic() - started) * 1000.0, 1)
        if not ok:
            self.last_loaded_at = None
        return ok

    def unload(self) -> None:
        """Release the YOLO model from memory and run garbage collection.

        Called by the pipeline immediately after detection so the PyTorch
        weights are never resident at the same time as the TensorFlow
        classifier (512 MiB deployment limit). Idempotent; ``load_error`` is
        preserved so ``/api/health`` keeps reporting the last real failure.
        """
        had_model = self._model is not None
        self._model = None
        gc.collect()
        if had_model:
            self.last_loaded_at = None
            logger.info("Detector released from memory.")

    def detect(self, image: np.ndarray, conf: Optional[float] = None) -> List[Dict]:
        """Run detection on a BGR image array (OpenCV convention)."""
        if not self.loaded:
            raise RuntimeError(self.load_error or "Detector model is not loaded.")
        threshold = settings.CONFIDENCE_THRESHOLD if conf is None else conf
        try:
            results = self._model.predict(source=image, conf=threshold, verbose=False)
        except Exception as exc:
            # Record the genuine runtime failure; /api/health reports it, the
            # client receives a safe message (never a stack trace).
            self.last_inference_ok = False
            self.last_inference_error = str(exc)[:300]
            logger.exception("Detector inference failed")
            raise
        self.last_inference_ok = True
        self.last_inference_error = None
        detections: List[Dict] = []
        for result in results:
            boxes = getattr(result, "boxes", None)
            if boxes is None:
                continue
            for box in boxes:
                x1, y1, x2, y2 = (float(value) for value in box.xyxy[0].tolist())
                class_id = int(box.cls[0].item())
                detections.append(
                    {
                        "bbox": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
                        "detection_confidence": round(float(box.conf[0].item()), 4),
                        "class": self._class_names.get(class_id, "onion"),
                    }
                )
        return detections
