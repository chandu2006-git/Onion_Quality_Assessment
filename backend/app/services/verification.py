"""Human verification rules.

The backend keeps AI observations and human decisions separate. These helpers
enforce the product rule that an inspection can only be finalised once every
detected bulb has been reviewed by the inspector, and they compute the verified
tallies used by the report.
"""

from typing import Dict, List, Optional, Sequence

from app.schemas.analysis import HealthLabel, OnionVerification, VerificationStatus

PENDING_MESSAGE = "Review all AI observations before finalizing the inspection."
MISSING_MESSAGE = "The submitted verification data does not cover every detected onion."


class VerificationError(ValueError):
    """Raised when submitted verification data is incomplete or inconsistent."""


def human_verification_label(ai_health: str, verification: Optional[OnionVerification]) -> str:
    """Label for the report column, preserving the original AI observation."""
    if verification is None:
        return "Pending"
    status = verification.verification_status.value
    if status == VerificationStatus.OVERRIDDEN.value:
        decision = verification.human_decision.value if verification.human_decision else "reviewed"
        return f"Marked {decision}"
    if status == VerificationStatus.CONFIRMED_AI.value:
        return f"Confirmed {ai_health}"
    return "Pending"


def summarise(verifications: Sequence[OnionVerification]) -> Dict[str, int]:
    """Count verification states and the resulting verified health tallies."""
    summary = {
        "pending": 0,
        "confirmed": 0,
        "overridden": 0,
        "verified_healthy": 0,
        "verified_unhealthy": 0,
    }
    for verification in verifications:
        status = verification.verification_status.value
        if status == VerificationStatus.PENDING.value:
            summary["pending"] += 1
        elif status == VerificationStatus.CONFIRMED_AI.value:
            summary["confirmed"] += 1
        else:
            summary["overridden"] += 1

        final = _final_health(verification)
        if final == HealthLabel.HEALTHY.value:
            summary["verified_healthy"] += 1
        elif final == HealthLabel.UNHEALTHY.value:
            summary["verified_unhealthy"] += 1
    return summary


def _final_health(verification: OnionVerification) -> Optional[str]:
    """Final recorded health for a bulb, never mutating the AI observation."""
    status = verification.verification_status.value
    if status == VerificationStatus.CONFIRMED_AI.value:
        return verification.ai_health.value
    if status == VerificationStatus.OVERRIDDEN.value and verification.human_decision is not None:
        return verification.human_decision.value
    return None


def unreviewed_ids(detection_ids: Sequence[int], verifications: Sequence[OnionVerification]) -> List[int]:
    """Detected bulbs that still have no human verification."""
    reviewed = {
        verification.id
        for verification in verifications
        if verification.verification_status.value != VerificationStatus.PENDING.value
    }
    return [detection_id for detection_id in detection_ids if detection_id not in reviewed]


def ensure_all_reviewed(detection_ids: Sequence[int], verifications: Sequence[OnionVerification]) -> None:
    """Raise :class:`VerificationError` unless every bulb has been reviewed."""
    covered = {verification.id for verification in verifications}
    if set(detection_ids) - covered:
        raise VerificationError(MISSING_MESSAGE)
    if unreviewed_ids(detection_ids, verifications):
        raise VerificationError(PENDING_MESSAGE)
