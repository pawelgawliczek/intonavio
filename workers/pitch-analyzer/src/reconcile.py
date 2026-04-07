"""Pure-function reconciliation of two pitch tracks.

Step 4 of the pitch quality roadmap: pYIN runs on the isolated vocal stem,
RMVPE runs on the original full mix. Both emit per-frame `(hz, confidence)`
estimates. This module combines them with 4 logical branches:

    1. Both unvoiced                     → unvoiced
    2. Both voiced, agree (< N semi)     → confidence-weighted log mean
    3. Both voiced, disagree (>= N semi) → pick the higher-confidence tracker
    4. Exactly one voiced                → use it if conf ≥ threshold, else unvoiced

The function takes aligned sequences — both inputs must share the same frame
grid (same length, same timestamps). Frame alignment (RMVPE's native 10 ms
hop at 16 kHz vs. pYIN's 11.6 ms hop at 44.1 kHz) is the caller's job —
this module is intentionally oblivious to timebases.

No I/O, no torch, no librosa — trivial to unit-test.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class PitchCandidate:
    """One frame of pitch from a single tracker.

    `hz` is None iff the tracker considers the frame unvoiced.
    `confidence` is in [0.0, 1.0]: pYIN's `voiced_prob`, or RMVPE's argmax
    softmax value. For unvoiced frames, confidence should be 0.0 (or whatever
    the tracker emits — the reconciler only inspects confidence when `hz`
    is not None).
    """

    hz: float | None
    confidence: float


@dataclass(frozen=True)
class ReconciledFrame:
    """One reconciled frame. `source` records which branch produced it — useful
    for debugging and ablation studies."""

    hz: float | None
    voiced: bool
    source: str  # 'unvoiced' | 'agree' | 'disagree_pyin' | 'disagree_rmvpe'
    #            | 'pyin_only' | 'rmvpe_only'


def _hz_to_semitones(hz: float) -> float:
    return 12.0 * math.log2(hz / 440.0)


def _semitone_distance(hz_a: float, hz_b: float) -> float:
    """Absolute distance between two frequencies in semitones."""
    return abs(_hz_to_semitones(hz_a) - _hz_to_semitones(hz_b))


def _log_weighted_mean(hz_a: float, w_a: float, hz_b: float, w_b: float) -> float:
    """Confidence-weighted geometric mean — operates in log(Hz) space."""
    total = w_a + w_b
    if total <= 0.0:
        return (hz_a + hz_b) / 2.0
    log_mean = (w_a * math.log(hz_a) + w_b * math.log(hz_b)) / total
    return math.exp(log_mean)


def reconcile_frame(
    pyin: PitchCandidate,
    rmvpe: PitchCandidate,
    *,
    pyin_voiced_thresh: float,
    rmvpe_voiced_thresh: float,
    agreement_semitones: float,
) -> ReconciledFrame:
    """Reconcile a single frame from two trackers.

    Thresholds are applied per-tracker — a candidate is considered "trusted
    voiced" iff it emits an hz AND its confidence meets that tracker's
    threshold.
    """
    pyin_trusted = pyin.hz is not None and pyin.confidence >= pyin_voiced_thresh
    rmvpe_trusted = rmvpe.hz is not None and rmvpe.confidence >= rmvpe_voiced_thresh

    # Branch 1 — neither tracker is trustworthy → unvoiced
    if not pyin_trusted and not rmvpe_trusted:
        return ReconciledFrame(hz=None, voiced=False, source="unvoiced")

    # Branch 4a — only pYIN is trustworthy
    if pyin_trusted and not rmvpe_trusted:
        assert pyin.hz is not None
        return ReconciledFrame(hz=pyin.hz, voiced=True, source="pyin_only")

    # Branch 4b — only RMVPE is trustworthy
    if rmvpe_trusted and not pyin_trusted:
        assert rmvpe.hz is not None
        return ReconciledFrame(hz=rmvpe.hz, voiced=True, source="rmvpe_only")

    # Both trusted — compare.
    assert pyin.hz is not None and rmvpe.hz is not None
    distance = _semitone_distance(pyin.hz, rmvpe.hz)

    if distance < agreement_semitones:
        # Branch 2 — agree → confidence-weighted log-space mean
        blended = _log_weighted_mean(
            pyin.hz, pyin.confidence, rmvpe.hz, rmvpe.confidence
        )
        return ReconciledFrame(hz=blended, voiced=True, source="agree")

    # Branch 3 — disagree → trust the higher-confidence tracker. Ties break
    # toward RMVPE because it sees the full mix and is architecturally more
    # robust against instrument bleed.
    if pyin.confidence > rmvpe.confidence:
        return ReconciledFrame(hz=pyin.hz, voiced=True, source="disagree_pyin")
    return ReconciledFrame(hz=rmvpe.hz, voiced=True, source="disagree_rmvpe")


def reconcile_tracks(
    pyin_frames: list[PitchCandidate],
    rmvpe_frames: list[PitchCandidate],
    *,
    pyin_voiced_thresh: float,
    rmvpe_voiced_thresh: float,
    agreement_semitones: float,
) -> list[ReconciledFrame]:
    """Reconcile two aligned pitch tracks frame-by-frame.

    Both lists must be the same length. Caller is responsible for resampling
    RMVPE's native timebase onto pYIN's frame grid before calling this.
    """
    if len(pyin_frames) != len(rmvpe_frames):
        raise ValueError(
            f"Frame count mismatch: pYIN={len(pyin_frames)}, RMVPE={len(rmvpe_frames)}"
        )
    return [
        reconcile_frame(
            p,
            r,
            pyin_voiced_thresh=pyin_voiced_thresh,
            rmvpe_voiced_thresh=rmvpe_voiced_thresh,
            agreement_semitones=agreement_semitones,
        )
        for p, r in zip(pyin_frames, rmvpe_frames, strict=True)
    ]
