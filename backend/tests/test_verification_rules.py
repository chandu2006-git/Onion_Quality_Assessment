"""Human verification rules: AI observation and human decision stay separate."""

import pytest

from app.schemas.analysis import (
    BoundingBox,
    Detection,
    HealthLabel,
    InspectionSummaryRequest,
    OnionVerification,
    VerificationStatus,
)
from app.services.verification import (
    MISSING_MESSAGE,
    PENDING_MESSAGE,
    VerificationError,
    ensure_all_reviewed,
    human_verification_label,
    summarise,
)

# NOTE: this payload is structural test data for the verification/report contract.
# It is not produced by - and can never be returned as - model inference output.
DETECTIONS = [
    Detection(
        id=1,
        bbox=BoundingBox(x1=10, y1=10, x2=120, y2=140),
        detection_confidence=0.94,
        health=HealthLabel.UNHEALTHY,
        health_confidence=0.83,
    ),
    Detection(
        id=2,
        bbox=BoundingBox(x1=140, y1=20, x2=260, y2=150),
        detection_confidence=0.88,
        health=HealthLabel.HEALTHY,
        health_confidence=0.97,
    ),
]


def _verification(identifier, status, decision=None):
    return OnionVerification(
        id=identifier,
        ai_health=DETECTIONS[identifier - 1].health,
        health_confidence=DETECTIONS[identifier - 1].health_confidence,
        detection_confidence=DETECTIONS[identifier - 1].detection_confidence,
        verification_status=status,
        human_decision=decision,
    )


def test_override_preserves_ai_observation():
    verification = _verification(1, VerificationStatus.OVERRIDDEN, HealthLabel.HEALTHY)
    assert verification.ai_health == HealthLabel.UNHEALTHY
    assert verification.human_decision == HealthLabel.HEALTHY
    assert human_verification_label("Unhealthy", verification) == "Marked Healthy"


def test_confirmation_labelled_with_ai_observation():
    verification = _verification(2, VerificationStatus.CONFIRMED_AI)
    assert human_verification_label("Healthy", verification) == "Confirmed Healthy"


def test_pending_verification_is_labelled_pending():
    assert human_verification_label("Healthy", _verification(2, VerificationStatus.PENDING)) == "Pending"


def test_summary_counts_states_and_verified_tallies():
    counts = summarise(
        [
            _verification(1, VerificationStatus.OVERRIDDEN, HealthLabel.HEALTHY),
            _verification(2, VerificationStatus.CONFIRMED_AI),
        ]
    )
    assert counts == {
        "pending": 0,
        "confirmed": 1,
        "overridden": 1,
        "verified_healthy": 2,
        "verified_unhealthy": 0,
    }


def test_finalisation_blocked_while_any_bulb_is_pending():
    with pytest.raises(VerificationError) as error:
        ensure_all_reviewed([1, 2], [_verification(1, VerificationStatus.CONFIRMED_AI), _verification(2, VerificationStatus.PENDING)])
    assert str(error.value) == PENDING_MESSAGE


def test_finalisation_blocked_when_coverage_is_incomplete():
    with pytest.raises(VerificationError) as error:
        ensure_all_reviewed([1, 2], [_verification(1, VerificationStatus.CONFIRMED_AI)])
    assert str(error.value) == MISSING_MESSAGE


def test_finalisation_allowed_once_every_bulb_is_reviewed():
    ensure_all_reviewed(
        [1, 2],
        [_verification(1, VerificationStatus.CONFIRMED_AI), _verification(2, VerificationStatus.OVERRIDDEN, HealthLabel.UNHEALTHY)],
    )


def test_report_payload_requires_verification_entries():
    payload = InspectionSummaryRequest(
        inspection_id="INS-TEST-0001",
        timestamp="01 Jan 2026, 10:00 UTC",
        inspector="Inspector",
        location="Pack-house",
        batch_lot="LOT-1",
        ai_healthy=1,
        ai_unhealthy=1,
        verified_healthy=1,
        verified_unhealthy=1,
        detections=DETECTIONS,
        verifications=[
            _verification(1, VerificationStatus.OVERRIDDEN, HealthLabel.HEALTHY),
            _verification(2, VerificationStatus.CONFIRMED_AI),
        ],
    )
    assert payload.detections[0].health == HealthLabel.UNHEALTHY
    assert payload.verifications[0].human_decision == HealthLabel.HEALTHY
