"""Request/response schemas for the analysis and verification endpoints."""

from enum import Enum
from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    x1: int = Field(ge=0)
    y1: int = Field(ge=0)
    x2: int = Field(ge=0)
    y2: int = Field(ge=0)


class HealthLabel(str, Enum):
    HEALTHY = "Healthy"
    UNHEALTHY = "Unhealthy"


class Detection(BaseModel):
    """One detected onion bulb with its immutable AI observation."""

    id: int
    bbox: BoundingBox
    detection_confidence: float = Field(ge=0, le=1)
    health: HealthLabel
    health_confidence: float = Field(ge=0, le=1)


class AnalysisResponse(BaseModel):
    inspection_id: str
    total_onions: int
    healthy: int
    unhealthy: int
    # Explicit count names required by the public API contract; they always
    # mirror total_onions / healthy / unhealthy.
    total_detected: int
    healthy_count: int
    unhealthy_count: int
    detections: List[Detection]
    annotated_image: str = Field(description="Base64 encoded annotated evidence image (JPEG).")
    # Actual pixel size of the annotated evidence image (the backend caps its
    # long side, so it can differ from the original upload dimensions).
    annotated_width: int = 0
    annotated_height: int = 0
    image_width: int
    image_height: int
    model_info: Dict[str, str] = Field(default_factory=dict)


class VerificationStatus(str, Enum):
    """Human verification state of a single bulb.

    The AI observation is never rewritten: a confirmed bulb keeps the AI label,
    an overridden bulb records the inspector's decision alongside it.
    """

    PENDING = "pending"
    CONFIRMED_AI = "confirmed_ai"
    OVERRIDDEN = "overridden"


class OnionVerification(BaseModel):
    """Human verification of a single bulb. AI fields are never overwritten."""

    id: int
    ai_health: HealthLabel
    health_confidence: float = Field(ge=0, le=1)
    detection_confidence: float = Field(ge=0, le=1)
    verification_status: VerificationStatus
    human_decision: Optional[HealthLabel] = None
    verification_note: Optional[str] = None


class InspectionSummaryRequest(BaseModel):
    """Payload used to build the PDF inspection report."""

    inspection_id: str
    timestamp: str
    inspector: str
    location: str
    batch_lot: str
    notes: Optional[str] = None
    ai_healthy: int = Field(ge=0)
    ai_unhealthy: int = Field(ge=0)
    verified_healthy: int = Field(ge=0)
    verified_unhealthy: int = Field(ge=0)
    detections: List[Detection]
    verifications: List[OnionVerification]
    annotated_image: Optional[str] = Field(
        default=None, description="Base64 annotated evidence image captured during analysis."
    )
