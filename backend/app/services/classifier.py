"""MobileNetV2 onion health classifier.

The trained Keras model is expected at ``settings.classifier_path``. The input
size, output activation, output width and (when present) the class names are
read from the model itself so that the real trained artefact - sigmoid or
softmax output - is interpreted correctly instead of being assumed.

``tensorflow`` is imported lazily inside :meth:`OnionHealthClassifier.load` so
the API can start and report an accurate error when the ML runtime is absent.

Weights are loaded on demand and released again via
:meth:`OnionHealthClassifier.unload` so the classifier and the detector are
never resident in memory at the same time (512 MiB deployment limit).
"""

import gc
import logging
import sys
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np

from app.config import settings

logger = logging.getLogger(__name__)

HEALTHY = "Healthy"
UNHEALTHY = "Unhealthy"

_HEALTHY_ALIASES = ("healthy", "good", "normal", "fresh")
_UNHEALTHY_ALIASES = ("unhealthy", "bad", "damaged", "rotten", "rot")


class OnionHealthClassifier:
    """Wrapper around the trained MobileNetV2 onion health classifier."""

    backend = "MobileNetV2"

    def __init__(self) -> None:
        self._model = None
        self._class_names: Optional[List[str]] = None
        self._input_size: int = settings.CLASSIFIER_INPUT_SIZE
        self._activation: str = "unknown"
        self._output_units: int = 0
        self.load_error: Optional[str] = None

    # ------------------------------------------------------------------ #
    # Lifecycle
    # ------------------------------------------------------------------ #
    @property
    def loaded(self) -> bool:
        return self._model is not None

    @property
    def model_path(self):
        return settings.classifier_path

    @property
    def input_size(self) -> int:
        return self._input_size

    @property
    def activation(self) -> str:
        return self._activation

    @property
    def output_units(self) -> int:
        return self._output_units

    @property
    def class_names(self) -> Optional[List[str]]:
        return list(self._class_names) if self._class_names else None

    def load(self) -> bool:
        """Load the classifier into memory. Returns True on success.

        Called lazily per analysis (never at application startup) and always
        paired with :meth:`unload` by the pipeline.
        """
        self._model = None
        self.load_error = None
        path = self.model_path
        if not path.is_file():
            self.load_error = f"Health classifier model file not found: {path.name}"
            logger.error("Health classifier model file not found at %s", path)
            return False
        try:
            import tensorflow as tf  # imported lazily: heavy dependency

            self._model = tf.keras.models.load_model(str(path), compile=False)
            self._read_model_metadata()
            logger.info(
                "Health classifier loaded from %s (input=%sx%s, activation=%s, units=%s, classes=%s)",
                path.name,
                self._input_size,
                self._input_size,
                self._activation,
                self._output_units,
                self._class_names or "not reported",
            )
            return True
        except Exception as exc:  # pragma: no cover - depends on local ML runtime
            self._model = None
            self.load_error = f"Health classifier could not be loaded: {exc}"
            logger.exception("Failed to load the health classifier model")
            return False

    def unload(self) -> None:
        """Release the Keras model from memory and run garbage collection.

        ``clear_session`` resets TensorFlow's global graph state so the freed
        memory can be reused instead of lingering in Keras caches. Called by
        the pipeline right after classification so the TensorFlow weights are
        never resident at the same time as the YOLO detector. Idempotent;
        ``load_error`` is preserved so ``/api/health`` keeps reporting the
        last real failure.
        """
        had_model = self._model is not None
        self._model = None
        tf = sys.modules.get("tensorflow")
        if tf is not None:
            try:
                tf.keras.backend.clear_session()
            except Exception:  # pragma: no cover - defensive
                logger.debug("tf.keras.backend.clear_session() failed during unload.", exc_info=True)
        gc.collect()
        if had_model:
            logger.info("Health classifier released from memory.")

    # ------------------------------------------------------------------ #
    # Inference
    # ------------------------------------------------------------------ #
    def classify(self, crop_bgr: np.ndarray) -> Dict:
        """Classify a single cropped onion (BGR array)."""
        import cv2  # imported lazily: opencv is only needed for inference

        if not self.loaded:
            raise RuntimeError(self.load_error or "Health classifier model is not loaded.")
        rgb = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGB)
        resized = cv2.resize(rgb, (self._input_size, self._input_size), interpolation=cv2.INTER_AREA)
        batch = (resized.astype(np.float32) / 255.0)[np.newaxis, ...]
        predictions = np.asarray(self._model.predict(batch, verbose=0)).reshape(-1)
        health, confidence, probabilities = self._interpret(predictions)
        return {
            "health": health,
            "health_confidence": round(float(confidence), 4),
            "probabilities": [round(float(value), 4) for value in probabilities],
        }
    # ------------------------------------------------------------------ #
    # Internals
    # ------------------------------------------------------------------ #
    def _read_model_metadata(self) -> None:
        """Read input size, activation, width and class names from the model."""
        model = self._model

        try:
            shape = model.input_shape
            if isinstance(shape, (list, tuple)) and shape and isinstance(shape[0], (list, tuple)):
                shape = shape[0]
            if shape and len(shape) >= 3 and shape[1] and shape[2]:
                self._input_size = int(shape[1])
        except Exception:  # pragma: no cover - defensive
            logger.warning("Could not read the classifier input shape; using %s", self._input_size)

        self._activation = "unknown"
        try:
            output_layer = model.layers[-1]
            activation = getattr(output_layer, "activation", None)
            self._activation = str(getattr(activation, "name", "unknown") or "unknown")
        except Exception:  # pragma: no cover - defensive
            logger.warning("Could not read the classifier output activation.")

        try:
            output_shape = model.output_shape
            if isinstance(output_shape, (list, tuple)) and output_shape and isinstance(output_shape[0], (list, tuple)):
                output_shape = output_shape[0]
            if output_shape and len(output_shape) > 1 and output_shape[-1]:
                self._output_units = int(output_shape[-1])
        except Exception:  # pragma: no cover - defensive
            logger.warning("Could not read the classifier output shape.")

        names: Optional[Sequence] = None
        for attribute in ("class_names", "classes"):
            value = getattr(model, attribute, None)
            if value is None or callable(value):
                continue
            try:
                candidate = [str(item) for item in value]
            except TypeError:
                continue
            if candidate:
                names = candidate
                break
        if names and (not self._output_units or len(names) == self._output_units):
            self._class_names = list(names)

    def _interpret(self, predictions: np.ndarray) -> Tuple[str, float, np.ndarray]:
        """Map the model output to Healthy/Unhealthy without swapping labels."""
        if predictions.size == 0:
            raise RuntimeError("The health classifier returned an empty prediction.")

        if predictions.size == 1:
            # Single sigmoid unit -> probability of the configured positive class.
            positive = float(predictions[0])
            positive_is_healthy = settings.CLASSIFIER_POSITIVE_CLASS.strip().lower() == HEALTHY.lower()
            healthy_prob = positive if positive_is_healthy else 1.0 - positive
            unhealthy_prob = 1.0 - healthy_prob
            health = HEALTHY if healthy_prob >= unhealthy_prob else UNHEALTHY
            return health, max(healthy_prob, unhealthy_prob), np.array([healthy_prob, unhealthy_prob])

        index = int(np.argmax(predictions))
        confidence = float(predictions[index])
        names = self._class_names
        if names and index < len(names):
            label = self._normalise(names[index])
        else:
            # Documented fallback: index 0 = Healthy, index 1 = Unhealthy, which
            # matches TensorFlow's sorted directory ordering used during training
            # (Healthy before Unhealthy).
            label = HEALTHY if index == 0 else UNHEALTHY
        return label, confidence, predictions

    @staticmethod
    def _normalise(name: str) -> str:
        lowered = str(name).strip().lower()
        if lowered.startswith(_HEALTHY_ALIASES):
            return HEALTHY
        if lowered.startswith(_UNHEALTHY_ALIASES):
            return UNHEALTHY
        logger.warning("Unrecognised classifier class name %r; reporting Unhealthy.", name)
        return UNHEALTHY

