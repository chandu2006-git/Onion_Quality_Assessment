"""PDF report tests: real generation from verified inspection data."""

import base64
import io

import pytest
from PIL import Image

from app.services.report_generator import _demo_qr_png, build_report
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


def test_qr_reference_is_a_valid_png():
    """The demo verification reference renders as a genuine PNG image."""
    png = _demo_qr_png(_payload())
    assert png.startswith(b"\x89PNG\r\n\x1a\n")
    assert len(png) > 100


def test_report_embeds_demo_qr_even_without_evidence_image():
    """The QR code section is part of the report itself (not the evidence image).

    With no annotated evidence image submitted, any raster image in the PDF can
    only be the demo QR code.
    """
    document = build_report(_payload(annotated_image=None))
    assert document.startswith(b"%PDF")
    assert b"/Image" in document


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


# --------------------------------------------------------------------------- #
# Demo provenance + quality-grade workflow
# --------------------------------------------------------------------------- #
def _demo_payload() -> InspectionSummaryRequest:
    """Same verified inspection, marked as a fixed demonstration scenario."""
    data = _payload().model_dump()
    data.update(
        is_demo=True,
        demo_scenario="01 - Healthy majority (5 healthy / 2 unhealthy)",
        demo_observations=[
            "7 bulbs detected on the bundled sample photograph.",
            "Spec split matches the demonstration dataset.",
        ],
        recommended_grade="GRADE B",
        final_grade="GRADE B",
        grade_decision="confirmed",
    )
    return InspectionSummaryRequest(**data)


def _pdf_text(document: bytes) -> str:
    """Extract the visible text of a generated PDF (whitespace-normalised)."""
    pypdf = pytest.importorskip("pypdf")
    reader = pypdf.PdfReader(io.BytesIO(document))
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    return " ".join(text.split())


def test_summary_schema_defaults_demo_and_grade_fields():
    """A plain (non-demo) payload keeps every new field optional."""
    payload = _payload()
    assert payload.is_demo is False
    assert payload.demo_scenario is None
    assert payload.demo_observations is None
    assert payload.recommended_grade is None
    assert payload.final_grade is None
    assert payload.grade_decision is None


def test_summary_schema_accepts_explicit_nulls_from_frontend():
    """The frontend submits explicit nulls for demo/grade keys — accepted."""
    data = _payload().model_dump()
    data.update(
        is_demo=False,
        demo_scenario=None,
        demo_observations=None,
        recommended_grade=None,
        final_grade=None,
        grade_decision=None,
    )
    payload = InspectionSummaryRequest(**data)
    assert payload.is_demo is False
    assert payload.recommended_grade is None


def test_demo_report_contains_banner_grade_block_and_demo_disclaimer():
    document = build_report(_demo_payload())
    assert document.startswith(b"%PDF")
    text = _pdf_text(document)
    # Prominent DEMO MODE banner + honest provenance.
    assert "DEMO MODE" in text
    assert "No AI model was executed" in text
    assert "01 - Healthy majority (5 healthy / 2 unhealthy)" in text
    # Quality grade block: recommendation, final grade and human decision.
    assert "QUALITY GRADE RECOMMENDATION" in text
    assert "FINAL GRADE (HUMAN)" in text
    assert "GRADE DECISION" in text
    assert "GRADE B" in text
    assert "Confirmed" in text
    assert "Under Relaxed Specifications" in text
    # Demo disclaimer + DEMO QR label.
    assert "fixed demonstration scenario" in text.lower()
    assert "SCAN FOR DIGITAL VERIFICATION (DEMO)" in text


def test_real_report_has_grade_block_but_no_demo_banner():
    data = _payload().model_dump()
    data.update(
        recommended_grade="GRADE A",
        final_grade="GRADE A",
        grade_decision="confirmed",
    )
    text = _pdf_text(build_report(InspectionSummaryRequest(**data)))
    assert "QUALITY GRADE RECOMMENDATION" in text
    assert "GRADE A" in text
    assert "DEMO MODE" not in text


def test_undecided_grade_shows_pending_everywhere():
    data = _payload().model_dump()
    data.update(
        recommended_grade="URS",
        final_grade="PENDING",
        grade_decision="pending",
    )
    text = _pdf_text(build_report(InspectionSummaryRequest(**data)))
    assert "URS" in text
    assert "PENDING" in text
    assert "Pending" in text


def test_report_endpoint_accepts_demo_payload(client):
    response = client.post("/api/report", json=_demo_payload().model_dump(mode="json"))
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF")
