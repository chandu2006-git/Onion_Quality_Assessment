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
    """Honest, granular service + model state.

    Four distinct signals are never conflated:

    * ``service_available``  - the API answered at all;
    * ``*_file_present``     - the trained artefacts are installed on disk;
    * ``*_loaded``           - weights are resident in memory *right now*
      (models load lazily per analysis, so both are normally false at rest);
    * ``analysis_available`` - an analysis request can run: files installed and
      no recorded load failure.

    ``last_inference_*`` reports the outcome of the most recent REAL inference.
    """

    status: str
    # Service readiness: trained files installed and no recorded load failure.
    ready: bool
    # The API answered this request (always true when this payload is served).
    service_available: bool = True
    # An analysis request can be served (files installed, no recorded failure).
    analysis_available: bool = True
    # ``loaded == false`` at rest is expected: weights load per analysis and are
    # released afterwards to stay inside the 512 MiB instance limit.
    lazy_loading: bool = True
    lazy_loading_note: str = (
        "Models load on demand during /api/analyze and are released afterwards; "
        "loaded=false at rest is the documented behaviour, not a failure."
    )
    # Current in-memory residency (models load lazily; false at rest).
    detector_loaded: bool
    classifier_loaded: bool
    detector_error: Optional[str] = None
    classifier_error: Optional[str] = None
    detector_file_present: bool
    classifier_file_present: bool
    version: str
    # --- Real load history (recorded, never guessed) ---------------------
    detector_load_attempts: int = 0
    classifier_load_attempts: int = 0
    detector_last_load_ok: Optional[bool] = None
    classifier_last_load_ok: Optional[bool] = None
    detector_last_load_ms: Optional[float] = None
    classifier_last_load_ms: Optional[float] = None
    # --- Last REAL inference ---------------------------------------------
    last_inference_ok: Optional[bool] = None
    last_inference_at: Optional[str] = None
    last_inference_ms: Optional[float] = None
    last_inference_bulbs: Optional[int] = None
    last_inspection_id: Optional[str] = None
    last_inference_error: Optional[str] = None
    inference_successes: int = 0
    inference_failures: int = 0
