"""Schemas describing the generated inspection report."""

from typing import List, Optional

from pydantic import BaseModel


class ModelInfo(BaseModel):
    role: str
    architecture: str
    file_name: str


class ReportResponse(BaseModel):
    inspection_id: str
    generated_at: str
    page_count: int
    models: List[ModelInfo]
    includes_evidence_image: bool
    includes_verification: bool
    limitations: List[str]


class HealthCheckResponse(BaseModel):
    status: str
    detector_loaded: bool
    classifier_loaded: bool
    detector_error: Optional[str] = None
    classifier_error: Optional[str] = None
    detector_file_present: bool
    classifier_file_present: bool
    version: str
