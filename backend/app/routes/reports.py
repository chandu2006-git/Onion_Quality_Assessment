"""Report endpoints: PDF generation from verified inspection data."""

import logging
from datetime import datetime, timezone
from typing import Dict

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.schemas.analysis import InspectionSummaryRequest
from app.schemas.report import ModelInfo, ReportResponse
from app.services.report_generator import LIMITATIONS, MODELS, build_report
from app.services.verification import VerificationError, ensure_all_reviewed

logger = logging.getLogger(__name__)

router = APIRouter(tags=["reports"])


def _guard_verification(payload: InspectionSummaryRequest) -> None:
    """An inspection is only finalised once every bulb has been reviewed."""
    try:
        ensure_all_reviewed([detection.id for detection in payload.detections], payload.verifications)
    except VerificationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _pdf_filename(inspection_id: str) -> str:
    safe = "".join(character for character in inspection_id if character.isalnum() or character in "-_")
    return f"ONION-DETECT-{safe or 'inspection-report'}.pdf"


@router.post("/report", response_class=Response, responses={200: {"content": {"application/pdf": {}}}})
def generate_report(payload: InspectionSummaryRequest) -> Response:
    """Build the inspection PDF. Returns the raw PDF document."""
    _guard_verification(payload)
    try:
        document = build_report(payload)
    except Exception:
        logger.exception("PDF generation failed for inspection %s", payload.inspection_id)
        raise HTTPException(
            status_code=500,
            detail="The inspection report could not be generated. Please try again.",
        )
    logger.info("Generated report for inspection %s (%s bytes)", payload.inspection_id, len(document))
    return Response(
        content=document,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{_pdf_filename(payload.inspection_id)}"'},
    )


@router.post("/report/summary", response_model=ReportResponse)
def report_summary(payload: InspectionSummaryRequest) -> ReportResponse:
    """Confirm the report can be built, without streaming the document."""
    _guard_verification(payload)
    try:
        document = build_report(payload)
    except Exception:
        logger.exception("Report summary generation failed for inspection %s", payload.inspection_id)
        raise HTTPException(
            status_code=500,
            detail="The inspection report could not be generated. Please try again.",
        )
    return ReportResponse(
        inspection_id=payload.inspection_id,
        generated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        page_count=max(1, document.count(b"/Type /Page ") - 1),
        models=[ModelInfo(**model) for model in MODELS],
        includes_evidence_image=bool(payload.annotated_image),
        includes_verification=bool(payload.verifications),
        limitations=list(LIMITATIONS),
    )


@router.get("/report/models", response_model=Dict[str, str])
def report_models() -> Dict[str, str]:
    return {model["role"]: f"{model['architecture']} — {model['file_name']}" for model in MODELS}
