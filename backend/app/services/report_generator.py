"""PDF inspection report generation (reportlab, no HTML/browser printing).

The report is built purely from the payload submitted by the inspector after
human verification. AI observations and human decisions are printed in separate
columns so the original AI observation is never overwritten.
"""

import base64
import io
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional, Sequence

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Image as PdfImage,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from app.config import settings
from app.schemas.analysis import InspectionSummaryRequest
from app.services.verification import human_verification_label, summarise

logger = logging.getLogger(__name__)

BRAND_GREEN = colors.HexColor("#12372A")
BRAND_GREEN_LIGHT = colors.HexColor("#2E6B4A")
BRAND_MINT = colors.HexColor("#E7F0EA")
OFF_WHITE = colors.HexColor("#F7F5EF")
CHARCOAL = colors.HexColor("#202622")
MUTED = colors.HexColor("#66716A")
BORDER = colors.HexColor("#D9E1DB")
AMBER = colors.HexColor("#D39B35")
HEALTHY_RED = colors.HexColor("#B03A3A")

MODELS: Sequence[Dict[str, str]] = (
    {
        "role": "Object Detection",
        "architecture": "YOLOv8n",
        # Report the artefact actually loaded, which can differ from the
        # configured default when the detector shipped under its short name.
        "file_name": settings.detector_path.name,
    },
    {
        "role": "Health Classification",
        "architecture": "MobileNetV2",
        "file_name": settings.classifier_path.name,
    },
)

LIMITATIONS = (
    "AI-assisted visual classification only.",
    "No disease-specific diagnosis.",
    "No calibrated diameter measurement.",
    "No internal quality assessment.",
    "No chemical or residue analysis.",
)

VERIFICATION_STATEMENT = (
    "The AI output represents an assisted observation. Final inspection status is recorded "
    "following human verification."
)

STANDARDS_NOTE = (
    "AGMARK / APEDA content referenced in this product is provided as standards context only. "
    "ONION DETECT is an AI-assisted inspection tool and does not automatically assign official "
    "AGMARK grades or replace regulatory inspection."
)


def _styles():
    styles = getSampleStyleSheet()
    return {
        "brand": ParagraphStyle(
            "Brand", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=20,
            leading=23, textColor=BRAND_GREEN, alignment=TA_LEFT, spaceAfter=2,
        ),
        "tagline": ParagraphStyle(
            "Tagline", parent=styles["Normal"], fontName="Helvetica", fontSize=9.5,
            leading=13, textColor=MUTED,
        ),
        "section": ParagraphStyle(
            "Section", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=11.5,
            leading=15, textColor=BRAND_GREEN, spaceBefore=10, spaceAfter=4,
        ),
        "workflow": ParagraphStyle(
            "Workflow", parent=styles["Normal"], fontName="Helvetica-Bold", fontSize=8.5,
            leading=12, textColor=BRAND_GREEN_LIGHT, spaceBefore=4, spaceAfter=2,
        ),
        "body": ParagraphStyle(
            "Body", parent=styles["Normal"], fontName="Helvetica", fontSize=9.5,
            leading=13.5, textColor=CHARCOAL,
        ),
        "small": ParagraphStyle(
            "Small", parent=styles["Normal"], fontName="Helvetica", fontSize=8.2,
            leading=11.5, textColor=MUTED,
        ),
        "label": ParagraphStyle(
            "Label", parent=styles["Normal"], fontName="Helvetica-Bold", fontSize=7.6,
            leading=10, textColor=MUTED,
        ),
        "value": ParagraphStyle(
            "Value", parent=styles["Normal"], fontName="Helvetica-Bold", fontSize=10,
            leading=13, textColor=CHARCOAL,
        ),
        "bullet": ParagraphStyle(
            "Bullet", parent=styles["Normal"], fontName="Helvetica", fontSize=9,
            leading=12.5, textColor=CHARCOAL, leftIndent=9, bulletIndent=0,
        ),
    }


def build_report(payload: InspectionSummaryRequest) -> bytes:
    """Render the inspection report. Returns the PDF file contents."""
    styles = _styles()
    buffer = io.BytesIO()
    document = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=16 * mm,
        rightMargin=16 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title=f"ONION DETECT Inspection Report {payload.inspection_id}",
        author="ONION DETECT",
        subject="AI-Assisted Onion Quality Inspection",
    )

    story: List = []
    story.extend(_masthead(styles))
    story.extend(_inspection_information(payload, styles))
    story.extend(_summary(payload, styles))
    story.extend(_observation_table(payload, styles))
    story.extend(_evidence(payload, styles))
    story.extend(_qr_section(payload, styles))
    story.extend(_models_section(styles))
    story.extend(_methodology_section(styles))
    story.extend(_verification_section(styles))
    story.append(Spacer(1, 8))
    story.extend(_limitations_section(styles))
    story.extend(_disclaimer(styles))

    document.build(story, onFirstPage=_page_furniture, onLaterPages=_page_furniture)
    return buffer.getvalue()


def _page_furniture(canvas, document) -> None:
    canvas.saveState()
    width, height = A4
    canvas.setStrokeColor(BORDER)
    canvas.setLineWidth(0.6)
    canvas.line(16 * mm, height - 14 * mm, width - 16 * mm, height - 14 * mm)
    canvas.line(16 * mm, 14 * mm, width - 16 * mm, 14 * mm)
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(16 * mm, height - 12.5 * mm, "ONION DETECT  |  AI-Assisted Onion Quality Inspection")
    canvas.drawRightString(width - 16 * mm, height - 12.5 * mm, "AI-assisted inspection — human verification required")
    canvas.drawString(16 * mm, 10 * mm, "Inspection report generated by ONION DETECT")
    canvas.drawRightString(width - 16 * mm, 10 * mm, f"Page {document.page}")
    canvas.restoreState()



# --------------------------------------------------------------------------- #
# Sections
# --------------------------------------------------------------------------- #
def _section_title(text: str, styles) -> List:
    table = Table([[Paragraph(text.upper(), styles["label"])]], colWidths=[168 * mm])
    table.setStyle(
        TableStyle(
            [
                ("LINEBELOW", (0, 0), (-1, -1), 0.8, BORDER),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    return [Spacer(1, 8), table, Spacer(1, 6)]


def _masthead(styles) -> List:
    header = Table(
        [
            [Paragraph("ONION DETECT", styles["brand"])],
            [Paragraph("AI-Assisted Onion Quality Inspection", styles["tagline"])],
        ],
        colWidths=[168 * mm],
    )
    header.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), BRAND_MINT),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (0, 0), 9),
                ("BOTTOMPADDING", (0, -1), (-1, -1), 9),
                ("LINEBELOW", (0, -1), (-1, -1), 1.2, BRAND_GREEN),
            ]
        )
    )
    return [
        header,
        Spacer(1, 6),
        # Product principle, stated on every report.
        Paragraph("AI MEASURES \u2192 HUMAN VERIFIES \u2192 EVIDENCE RECORDED", styles["workflow"]),
        Paragraph("INSPECTION REPORT", styles["section"]),
    ]


def _inspection_information(payload: InspectionSummaryRequest, styles) -> List:
    story = _section_title("1. Inspection Information", styles)
    rows = [
        ("Inspection ID", payload.inspection_id, "Date / Time", payload.timestamp),
        ("Inspector", payload.inspector, "Location", payload.location),
        ("Batch / Lot", payload.batch_lot, "Report Generated", _now()),
    ]
    table_rows = [
        [
            Paragraph(left_label, styles["label"]),
            Paragraph(str(left_value), styles["value"]),
            Paragraph(right_label, styles["label"]),
            Paragraph(str(right_value), styles["value"]),
        ]
        for left_label, left_value, right_label, right_value in rows
    ]
    table = Table(table_rows, colWidths=[27 * mm, 57 * mm, 30 * mm, 54 * mm])
    table.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
                ("BACKGROUND", (0, 0), (0, -1), OFF_WHITE),
                ("BACKGROUND", (2, 0), (2, -1), OFF_WHITE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(table)
    if payload.notes:
        story.append(Spacer(1, 5))
        story.append(Paragraph("Inspection notes", styles["label"]))
        story.append(Paragraph(str(payload.notes), styles["body"]))
    return story


def _summary(payload: InspectionSummaryRequest, styles) -> List:
    story = _section_title("2. Inspection Summary", styles)
    header = [
        Paragraph("TOTAL ONIONS", styles["label"]),
        Paragraph("AI HEALTHY", styles["label"]),
        Paragraph("AI UNHEALTHY", styles["label"]),
        Paragraph("VERIFIED HEALTHY", styles["label"]),
        Paragraph("VERIFIED UNHEALTHY", styles["label"]),
    ]
    values = [
        Paragraph(str(len(payload.detections)), styles["value"]),
        Paragraph(str(payload.ai_healthy), styles["value"]),
        Paragraph(str(payload.ai_unhealthy), styles["value"]),
        Paragraph(str(payload.verified_healthy), styles["value"]),
        Paragraph(str(payload.verified_unhealthy), styles["value"]),
    ]
    table = Table([header, values], colWidths=[33.6 * mm] * 5)
    table.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
                ("BACKGROUND", (0, 0), (-1, 0), OFF_WHITE),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 4))
    story.append(
        Paragraph(
            "AI observations and verified results are listed separately: the AI column records what the "
            "classifier observed, the verified column records the inspector's final decision.",
            styles["small"],
        )
    )
    return story


def _observation_table(payload: InspectionSummaryRequest, styles) -> List:
    story = _section_title("3. Individual Observations", styles)
    verifications = {item.id: item for item in payload.verifications}
    header = [
        Paragraph("ONION", styles["label"]),
        Paragraph("AI OBSERVATION", styles["label"]),
        Paragraph("HEALTH CONF.", styles["label"]),
        Paragraph("DETECTION CONF.", styles["label"]),
        Paragraph("HUMAN VERIFICATION", styles["label"]),
        Paragraph("STATUS", styles["label"]),
    ]
    rows = [header]
    for detection in payload.detections:
        verification = verifications.get(detection.id)
        human = human_verification_label(detection.health.value, verification)
        status = verification.verification_status.value.replace("_", " ") if verification else "pending"
        rows.append(
            [
                Paragraph(f"#{detection.id:02d}", styles["body"]),
                Paragraph(detection.health.value, styles["body"]),
                Paragraph(f"{detection.health_confidence * 100:.1f}%", styles["body"]),
                Paragraph(f"{detection.detection_confidence * 100:.1f}%", styles["body"]),
                Paragraph(human, styles["body"]),
                Paragraph(status, styles["small"]),
            ]
        )
    table = Table(rows, colWidths=[16 * mm, 30 * mm, 24 * mm, 28 * mm, 40 * mm, 30 * mm], repeatRows=1)
    style = [
        ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
        ("BACKGROUND", (0, 0), (-1, 0), OFF_WHITE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    for index, detection in enumerate(payload.detections, start=1):
        colour = BRAND_GREEN_LIGHT if detection.health.value == "Healthy" else HEALTHY_RED
        style.append(("TEXTCOLOR", (1, index), (1, index), colour))
    table.setStyle(TableStyle(style))
    story.append(table)
    story.append(Spacer(1, 4))
    # Verification summary (honest counts computed from the submitted data).
    counts = summarise(payload.verifications)
    total = len(payload.detections)
    mismatches = sum(
        1
        for item in payload.verifications
        if item.verification_status.value == "overridden"
        and item.human_decision is not None
        and item.human_decision.value != item.ai_health.value
    )
    if counts["pending"]:
        verification_line = (
            f"Verification summary: {total} bulb(s) inspected \u2014 {counts['confirmed']} AI confirmed, "
            f"{mismatches} AI\u2013human mismatch(es), {counts['overridden']} override(s). "
            f"VERIFICATION PENDING \u2014 {counts['pending']} of {total} bulb(s) still to review."
        )
    else:
        verification_line = (
            f"Verification summary: {total} bulb(s) inspected \u2014 {counts['confirmed']} AI confirmed, "
            f"{mismatches} AI\u2013human mismatch(es), {counts['overridden']} override(s). "
            f"Human verified {total}/{total} (100%); verified final result: "
            f"{counts['verified_healthy']} Healthy / {counts['verified_unhealthy']} Unhealthy."
        )
    story.append(Paragraph(verification_line, styles["small"]))
    return story




def _evidence(payload: InspectionSummaryRequest, styles) -> List:
    story = _section_title("4. Evidence", styles)
    image = _decode_evidence(payload.annotated_image)
    if image is None:
        story.append(
            Paragraph("No annotated evidence image was submitted with this inspection record.", styles["small"])
        )
        return story
    max_width = 168 * mm
    ratio = (image.imageHeight / float(image.imageWidth)) if image.imageWidth else 0.75
    image.drawWidth = max_width
    image.drawHeight = min(max_width * ratio, 150 * mm)
    story.append(image)
    story.append(Spacer(1, 4))
    story.append(
        Paragraph(
            "Annotated sample image produced during AI analysis. Bounding boxes and bulb numbers "
            "correspond to the observation table above.",
            styles["small"],
        )
    )
    return story


def _demo_qr_reference(payload: InspectionSummaryRequest) -> str:
    """Self-contained DEMO verification reference encoded in the QR code.

    Deliberately NOT a URL: no public verification endpoint exists, so the QR
    encodes plain inspection text that any scanner can display, clearly marked
    as a demo reference (never an official government verification).
    """
    return (
        "ONION DETECT - DEMO VERIFICATION REFERENCE\n"
        f"Inspection: {payload.inspection_id}\n"
        f"Batch: {payload.batch_lot}\n"
        f"Inspector: {payload.inspector}\n"
        f"Location: {payload.location}\n"
        f"Generated: {_now()}\n"
        "Demo only - not linked to any official government verification system. "
        "AI-assisted record; human verified."
    )


def _demo_qr_png(payload: InspectionSummaryRequest) -> bytes:
    """Render the demo verification reference as a PNG image."""
    import qrcode  # imported lazily: only needed when a report is built

    qr = qrcode.QRCode(
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=6,
        border=2,
    )
    qr.add_data(_demo_qr_reference(payload))
    qr.make(fit=True)
    image = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _qr_section(payload: InspectionSummaryRequest, styles) -> List:
    story = _section_title("5. Digital Verification (Demo QR)", styles)
    try:
        qr_image = PdfImage(io.BytesIO(_demo_qr_png(payload)))
    except Exception:  # pragma: no cover - defensive
        logger.warning("Demo QR reference could not be generated; omitting it from the report.")
        story.append(
            Paragraph(
                "The demo verification reference could not be generated for this report.",
                styles["small"],
            )
        )
        return story
    side = 30 * mm
    qr_image.drawWidth = side
    qr_image.drawHeight = side
    caption = [
        Paragraph("SCAN FOR DIGITAL VERIFICATION (DEMO)", styles["label"]),
        Spacer(1, 4),
        Paragraph(
            f"Encodes a self-contained demo reference for inspection <b>{payload.inspection_id}</b> "
            f"(batch {payload.batch_lot}). Scanning displays the inspection reference text. "
            "This is a DEMO verification reference only: ONION DETECT is not connected to any "
            "official government verification system, and scanning does not constitute official "
            "verification or certification.",
            styles["body"],
        ),
    ]
    table = Table([[qr_image, caption]], colWidths=[36 * mm, 132 * mm])
    table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    story.append(table)
    return story


def _models_section(styles) -> List:
    story = _section_title("6. Models Used", styles)
    rows = [
        [
            Paragraph("ROLE", styles["label"]),
            Paragraph("ARCHITECTURE", styles["label"]),
            Paragraph("MODEL FILE", styles["label"]),
        ]
    ]
    for model in MODELS:
        rows.append(
            [
                Paragraph(model["role"], styles["body"]),
                Paragraph(model["architecture"], styles["body"]),
                Paragraph(model["file_name"], styles["small"]),
            ]
        )
    table = Table(rows, colWidths=[45 * mm, 45 * mm, 78 * mm])
    table.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
                ("BACKGROUND", (0, 0), (-1, 0), OFF_WHITE),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(table)
    return story


def _methodology_section(styles) -> List:
    return _section_title("7. Methodology Note", styles) + [
        Paragraph(
            "Each detected onion is individually cropped and evaluated by the health classification model. "
            "Detection confidence describes how confidently the bulb was located; health confidence "
            "describes how confidently the crop was classified as Healthy or Unhealthy.",
            styles["body"],
        )
    ]


def _verification_section(styles) -> List:
    return _section_title("8. Human Verification Statement", styles) + [
        Paragraph(VERIFICATION_STATEMENT, styles["body"])
    ]


def _limitations_section(styles) -> List:
    story = _section_title("9. Limitations and Standards Context", styles)
    story.append(Paragraph(STANDARDS_NOTE, styles["body"]))
    story.append(Spacer(1, 5))
    for limitation in LIMITATIONS:
        story.append(Paragraph(limitation, styles["bullet"], bulletText="\u2022"))
    return story


def _disclaimer(styles) -> List:
    return _section_title("10. Disclaimer", styles) + [
        Paragraph(
            "AI observations are subject to human verification and should not be treated as a substitute "
            "for expert or regulatory inspection.",
            styles["body"],
        ),
        Spacer(1, 4),
        Paragraph(
            "AI classification is subject to human verification. This report is an "
            "inspection-support record and is not a regulatory certification.",
            styles["body"],
        ),
    ]



# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _now() -> str:
    return datetime.now(timezone.utc).strftime("%d %b %Y, %H:%M UTC")


def _decode_evidence(encoded: Optional[str]):
    """Decode the base64 annotated image into a reportlab Image flowable."""
    if not encoded:
        return None
    payload = encoded.split(",", 1)[-1] if encoded.startswith("data:") else encoded
    try:
        raw = base64.b64decode(payload, validate=False)
    except Exception:
        logger.warning("Annotated evidence image could not be decoded; omitting it from the report.")
        return None
    if not raw:
        return None
    try:
        # Normalise through Pillow so unusual encodings cannot break the PDF build.
        from PIL import Image as PillowImage

        with PillowImage.open(io.BytesIO(raw)) as source:
            converted = io.BytesIO()
            source.convert("RGB").save(converted, format="JPEG", quality=88, optimize=True)
        converted.seek(0)
        return PdfImage(converted)
    except Exception:
        logger.warning("Annotated evidence image could not be prepared for the PDF.")
        return None
