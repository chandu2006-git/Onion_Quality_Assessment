"""Process-wide inference diagnostics.

``/api/health`` and ``/api/models`` must report an honest model state, so the
service records what actually happened instead of inferring it from a transient
in-memory flag:

* which model files are installed;
* whether a model load was attempted, and whether it succeeded (with the real
  error message when it did not);
* the outcome and duration of the last real inference.

Models are still loaded lazily and released after use (the free Render instance
has 512 MiB), so ``loaded == false`` at rest is expected and is NOT reported as
a failure. This module only records facts.
"""

from __future__ import annotations

import threading
import time
from datetime import datetime, timezone
from typing import Any, Dict, Optional

# Longest error string exposed through the diagnostics endpoints. Real stack
# traces never leave the server log; the message is already a safe summary.
MAX_ERROR_LENGTH = 300


def _iso(epoch_seconds: Optional[float]) -> Optional[str]:
    if epoch_seconds is None:
        return None
    return datetime.fromtimestamp(epoch_seconds, tz=timezone.utc).isoformat(timespec="seconds")


class InferenceDiagnostics:
    """Thread-safe record of the last real inference."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._last_ok: Optional[bool] = None
        self._last_started_at: Optional[float] = None
        self._last_finished_at: Optional[float] = None
        self._last_duration_ms: Optional[float] = None
        self._last_bulbs: Optional[int] = None
        self._last_inspection_id: Optional[str] = None
        self._last_error: Optional[str] = None
        self._successes = 0
        self._failures = 0

    # -- recording ----------------------------------------------------- #
    def started(self) -> float:
        """Mark the start of an inference and return a monotonic timestamp."""
        started = time.monotonic()
        with self._lock:
            self._last_started_at = time.time()
        return started

    def succeeded(self, *, started: float, bulbs: int, inspection_id: str) -> None:
        with self._lock:
            self._last_ok = True
            self._last_finished_at = time.time()
            self._last_duration_ms = round((time.monotonic() - started) * 1000.0, 1)
            self._last_bulbs = bulbs
            self._last_inspection_id = inspection_id
            self._last_error = None
            self._successes += 1

    def failed(self, *, message: str) -> None:
        with self._lock:
            self._last_ok = False
            self._last_finished_at = time.time()
            self._last_error = str(message)[:MAX_ERROR_LENGTH]
            self._failures += 1

    # -- reporting ----------------------------------------------------- #
    def snapshot(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "last_inference_ok": self._last_ok,
                "last_inference_at": _iso(self._last_finished_at),
                "last_inference_started_at": _iso(self._last_started_at),
                "last_inference_ms": self._last_duration_ms,
                "last_inference_bulbs": self._last_bulbs,
                "last_inspection_id": self._last_inspection_id,
                "last_inference_error": self._last_error,
                "inference_successes": self._successes,
                "inference_failures": self._failures,
                "any_inference_succeeded": self._successes > 0,
            }


# Shared instance: the pipeline records into it, the health routes read it.
inference = InferenceDiagnostics()
