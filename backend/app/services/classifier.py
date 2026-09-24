"""MobileNetV2 onion health classifier.

The trained TFLite model is expected at ``settings.classifier_path``.

The classifier uses LiteRT for lightweight CPU inference. The model is loaded
on demand and released after inference so the detector and classifier are
never resident in memory at the same time.
"""

from __future__ import annotations

import gc
import logging
from pathlib import Path
from typing import Any

import cv2
import numpy as np

from app.config import settings

HEALTHY = "Healthy"
UNHEALTHY = "Unhealthy"

logger = logging.getLogger(__name__)


class OnionHealthClassifier:
    """Lightweight LiteRT onion health classifier."""

    def __init__(self) -> None:
        self._interpreter: Any | None = None
        self._input_details: list[dict[str, Any]] = []
        self._output_details: list[dict[str, Any]] = []
        self._input_shape: tuple[int, ...] | None = None

        self._class_names = [HEALTHY, UNHEALTHY]
        self._positive_class = UNHEALTHY

        # Backend identifier used by API metadata.
        self.backend = "LiteRT"
        # Kept for compatibility with the existing pipeline.
        self.load_error: str | None = None

    @property
    def loaded(self) -> bool:
        """Return whether the LiteRT interpreter is currently loaded."""
        return self._interpreter is not None

    def load(self) -> bool:
        """Load the TFLite model into memory."""
        if self.loaded:
            return True

        model_path = Path(settings.classifier_path)

        if not model_path.exists():
            self.load_error = f"Classifier model not found: {model_path}"
            logger.error(self.load_error)
            return False

        if model_path.suffix.lower() != ".tflite":
            self.load_error = (
                f"Classifier path must point to a .tflite model: {model_path}"
            )
            logger.error(self.load_error)
            return False

        self.load_error = None

        try:
            from ai_edge_litert import interpreter as tflite

            logger.info(
                "Loading LiteRT classifier from %s",
                model_path,
            )

            interpreter = tflite.Interpreter(
                model_path=str(model_path)
            )

            interpreter.allocate_tensors()

            input_details = interpreter.get_input_details()
            output_details = interpreter.get_output_details()

            if not input_details:
                raise RuntimeError(
                    "TFLite model has no input tensor"
                )

            if not output_details:
                raise RuntimeError(
                    "TFLite model has no output tensor"
                )

            self._interpreter = interpreter
            self._input_details = input_details
            self._output_details = output_details

            self._input_shape = tuple(
                int(value)
                for value in input_details[0]["shape"]
            )

            logger.info(
                "LiteRT classifier loaded successfully: "
                "input=%s output=%s",
                input_details[0]["shape"],
                output_details[0]["shape"],
            )

            return True

        except Exception as exc:
            self.load_error = str(exc)

            logger.exception(
                "Failed to load LiteRT classifier"
            )

            self.unload()

            return False

    def unload(self) -> None:
        """Release the LiteRT interpreter and associated memory."""
        self._interpreter = None
        self._input_details = []
        self._output_details = []
        self._input_shape = None

        gc.collect()

        logger.info(
            "LiteRT classifier released from memory"
        )

    def classify(
        self,
        image: np.ndarray,
    ) -> dict[str, Any]:
        """Classify one onion crop as Healthy or Unhealthy."""

        if not self.loaded:
            raise RuntimeError(
                "Classifier is not loaded"
            )

        if image is None or image.size == 0:
            raise ValueError(
                "Invalid image supplied to classifier"
            )

        # ---------------------------------------------------------
        # Preprocessing
        # ---------------------------------------------------------
        # Match the original production classifier:
        #
        # BGR
        #   ↓
        # RGB
        #   ↓
        # 224 x 224
        #   ↓
        # float32
        #   ↓
        # /255
        #   ↓
        # batch dimension
        # ---------------------------------------------------------

        rgb = cv2.cvtColor(
            image,
            cv2.COLOR_BGR2RGB,
        )

        rgb = cv2.resize(
            rgb,
            (224, 224),
        )

        batch = (
            rgb.astype(np.float32) / 255.0
        )

        batch = np.expand_dims(
            batch,
            axis=0,
        )

        input_detail = self._input_details[0]
        output_detail = self._output_details[0]

        # Make sure input dtype matches the TFLite model.
        input_dtype = input_detail["dtype"]

        if batch.dtype != input_dtype:
            batch = batch.astype(input_dtype)

        # ---------------------------------------------------------
        # TFLite / LiteRT inference
        # ---------------------------------------------------------

        self._interpreter.set_tensor(
            input_detail["index"],
            batch,
        )

        self._interpreter.invoke()

        output = self._interpreter.get_tensor(
            output_detail["index"]
        )

        return self._interpret(output)

    def _interpret(
        self,
        output: np.ndarray,
    ) -> dict[str, Any]:
        """Convert model output into the existing API format."""

        values = np.asarray(output).reshape(-1)

        if values.size == 0:
            raise RuntimeError(
                "Classifier returned an empty output"
            )

        # ---------------------------------------------------------
        # Binary sigmoid model
        # ---------------------------------------------------------
        #
        # The trained MobileNetV2 model has:
        #
        # input  = (1, 224, 224, 3)
        # output = (1, 1)
        #
        # The sigmoid output represents the probability of
        # Unhealthy.
        # ---------------------------------------------------------

        if values.size == 1:
            unhealthy_probability = float(
                np.clip(
                    values[0],
                    0.0,
                    1.0,
                )
            )

            healthy_probability = (
                1.0 - unhealthy_probability
            )

            if (
                self._positive_class
                == UNHEALTHY
            ):
                if unhealthy_probability >= 0.5:
                    health = UNHEALTHY
                    confidence = (
                        unhealthy_probability
                    )
                else:
                    health = HEALTHY
                    confidence = (
                        healthy_probability
                    )
            else:
                if unhealthy_probability >= 0.5:
                    health = self._positive_class
                    confidence = (
                        unhealthy_probability
                    )
                else:
                    health = HEALTHY
                    confidence = (
                        healthy_probability
                    )

            return {
                "health": health,
                "confidence": float(confidence),
                "health_confidence": float(
                    confidence
                ),
                "probabilities": {
                    HEALTHY: float(
                        healthy_probability
                    ),
                    UNHEALTHY: float(
                        unhealthy_probability
                    ),
                },
            }

        # ---------------------------------------------------------
        # Generic multi-class fallback
        # ---------------------------------------------------------

        probabilities = values.astype(
            np.float64
        )

        total = probabilities.sum()

        if total > 0:
            probabilities = (
                probabilities / total
            )

        index = int(
            np.argmax(probabilities)
        )

        if index >= len(
            self._class_names
        ):
            index = (
                len(self._class_names) - 1
            )

        health = self._class_names[index]

        confidence = float(
            probabilities[index]
        )

        probability_map = {
            name: float(
                probabilities[i]
            )
            for i, name in enumerate(
                self._class_names[
                    : len(probabilities)
                ]
            )
        }

        return {
            "health": health,
            "confidence": confidence,
            "health_confidence": confidence,
            "probabilities": probability_map,
        }