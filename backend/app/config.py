import logging
import re
from pathlib import Path
from typing import List, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict

# backend/ directory - used to resolve relative model paths consistently
# regardless of the working directory the process was started from.
BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    """Runtime configuration (environment variables / backend/.env)."""

    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- API metadata -------------------------------------------------
    API_TITLE: str = "ONION DETECT API"
    API_DESCRIPTION: str = "AI-Assisted Onion Quality Inspection API"
    API_VERSION: str = "1.0.0"

    # --- Model configuration ------------------------------------------
    MODEL_DETECTOR_PATH: str = "models/onion_detector_v1.pt"
    MODEL_HEALTH_CLASSIFIER_PATH: str = "models/onion_health_mobilenetv2_best.keras"

    # --- Server -------------------------------------------------------
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    # Comma separated allowed frontend origins. Entries containing "*" are
    # compiled into an origin regex (see cors_origin_regex), so local Flutter Web
    # development works on any dynamically assigned port, e.g.:
    #   http://localhost,http://localhost:*,http://127.0.0.1,http://127.0.0.1:*
    CORS_ORIGINS: str = (
        "http://localhost,http://localhost:*,"
        "http://127.0.0.1,http://127.0.0.1:*,"
        "http://localhost:8080,http://localhost:3000"
    )
    LOG_LEVEL: str = "INFO"

    # --- Upload / inference -------------------------------------------
    MAX_UPLOAD_SIZE_MB: int = 10
    CONFIDENCE_THRESHOLD: float = 0.25
    # Uploads larger than this are downscaled for detection only. Detection
    # boxes are mapped back to original image coordinates before returning.
    MAX_INFERENCE_SIDE: int = 1600
    # Long side of the annotated evidence image returned to the client / embedded
    # in the PDF. Keeps the JSON payload and the PDF page size bounded.
    EVIDENCE_IMAGE_MAX_SIDE: int = 1920
    ANNOTATED_IMAGE_QUALITY: int = 88
    # Fallback input size, used only when the .keras model does not expose one.
    CLASSIFIER_INPUT_SIZE: int = 224
    # Class represented by the single sigmoid output of a binary classifier.
    # TensorFlow directory-ordered training puts "Healthy" at index 0 and
    # "Unhealthy" at index 1, therefore the sigmoid unit estimates Unhealthy.
    # Change this value in the environment if the trained model was built with
    # the opposite convention.
    CLASSIFIER_POSITIVE_CLASS: str = "Unhealthy"

    @staticmethod
    def _resolve(value: str) -> Path:
        path = Path(value)
        return path if path.is_absolute() else (BASE_DIR / path).resolve()

    @property
    def detector_path(self) -> Path:
        path = self._resolve(self.MODEL_DETECTOR_PATH)
        if path.is_file():
            return path
        # The trained detector has shipped under both "onion_detector_v1.pt"
        # and "onion_detector.pt". Accept either genuine artefact rather than
        # reporting the model as missing.
        for alias in ("onion_detector_v1.pt", "onion_detector.pt"):
            candidate = path.with_name(alias)
            if candidate.is_file():
                return candidate
        return path

    @property
    def classifier_path(self) -> Path:
        return self._resolve(self.MODEL_HEALTH_CLASSIFIER_PATH)

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def cors_origin_regex(self) -> Optional[str]:
        """Regex for wildcard origin entries such as ``http://localhost:*``.

        Starlette's CORSMiddleware accepts an Origin when this pattern
        ``fullmatch``es, so Flutter Web's dynamically assigned development port
        is allowed while only the configured hosts (localhost / 127.0.0.1) can
        match. The literal ``"*"`` origin is never produced here; credentials
        remain disabled in main.py, so no wildcard-with-credentials conflict
        can occur.
        """
        patterns: List[str] = []
        for origin in self.cors_origins_list:
            if "*" not in origin:
                continue
            prefix, _, suffix = origin.partition("*")
            # Wildcard matches within the origin only (no "/" boundaries).
            patterns.append(re.escape(prefix) + "[^/]*" + re.escape(suffix))
        return "|".join(patterns) if patterns else None

    @property
    def max_upload_size_bytes(self) -> int:
        return self.MAX_UPLOAD_SIZE_MB * 1024 * 1024

    @property
    def models_present(self) -> bool:
        return self.detector_path.is_file() and self.classifier_path.is_file()


settings = Settings()


def configure_logging() -> None:
    """Configure application logging (technical detail stays in the console)."""
    logging.basicConfig(
        level=getattr(logging, str(settings.LOG_LEVEL).upper(), logging.INFO),
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    )
