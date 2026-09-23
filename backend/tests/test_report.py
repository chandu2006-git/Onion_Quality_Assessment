"""PDF report tests: real generation from verified inspection data."""

import base64
import io

from PIL import Image

from app.services.report_generator import build_report
from app.schemas.analysis import (
    HealthLabel,
    InspectionSummaryRequest,
    OnionVerification,
    VerificationStatus,
)
from tests.conftest import make_png_bytes
from tests.test_verification_rules import DETECTIONS
from tests.test_verification_rules import _verification


def _payload(verifications=None, annotated_image=None) -> InspectionSummaryRequest:
    return InspectionSummaryRequest(
        inspection_id="INS-2026-ABC123",
        timestamp="23 Sep 2026, 09:15 UTC",
        inspector="Inspector Name",
        location="Pack-house 2, Nashik",
        batch_lot="LOT-A-118",
        notes="Sample drawn from the outer rows of the storage crate.",
        ai_healthy=1,
        ai_unhealthy=1,
        verified_healthy=2,
        verified_unhealthy=0,
        detections=DETECTIONS,
        verifications=verifications
        or [
            _verification(1, VerificationStatus.OVERRIDDEN, HealthLabel.HEALTHY),
            _verification(2, VerificationStatus.CONFIRMED_AI),
        ],
        annotated_image=annotated_image,
    )


def _evidence_base64() -> str:
    buffer = io.BytesIO()
    Image.new("RGB", (800, 600), (60, 110, 70)).save(buffer, format="JPEG")
    return base64.b64encode(buffer.getvalue()).decode("ascii")


def test_pdf_is_generated_from_verified_data():
    document = build_report(_payload())
    assert document.startswith(b"%PDF")
    assert len(document) > 2000


def test_pdf_embeds_annotated_evidence_image():
    with_evidence = build_report(_payload(annotated_image=_evidence_base64()))
    without_evidence = build_report(_payload())
    assert with_evidence.startswith(b"%PDF")
    assert len(with_evidence) > len(without_evidence) + 1000


def test_pdf_generation_survives_unreadable_evidence():
    document = build_report(_payload(annotated_image=base64.b64encode(b"broken").decode("ascii")))
    assert document.startswith(b"%PDF")


def test_report_endpoint_returns_pdf_and_rejects_pending_verification(client):
    verified = client.post("/api/report", json=_payload().model_dump(mode="json"))
    assert verified.status_code == 200
    assert verified.headers["content-type"] == "application/pdf"
    assert "INS-2026-ABC123" in verified.headers["content-disposition"]
    assert verified.content.startswith(b"%PDF")

    pending = _payload(verifications=[_verification(1, VerificationStatus.PENDING), _verification(2, VerificationStatus.CONFIRMED_AI)])
    blocked = client.post("/api/report", json=pending.model_dump(mode="json"))
    assert blocked.status_code == 400
    assert "review all ai observations" in blocked.json()["detail"].lower()


def test_report_summary_describes_the_document(client):
    response = client.post("/api/report/summary", json=_payload(annotated_image=_evidence_base64()).model_dump(mode="json"))
    assert response.status_code == 200
    payload = response.json()
    assert payload["inspection_id"] == "INS-2026-ABC123"
    assert payload["includes_evidence_image"] is True
    assert payload["includes_verification"] is True
    assert payload["page_count"] >= 1
    roles = {model["role"] for model in payload["models"]}
    assert roles == {"Object Detection", "Health Classification"}
    assert any("No disease-specific diagnosis." == item for item in payload["limitations"])
