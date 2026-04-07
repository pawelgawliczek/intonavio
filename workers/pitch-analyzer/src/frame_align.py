"""Pure-function frame-grid alignment between two pitch tracks.

Used to resample RMVPE's native 10 ms hop @ 16 kHz onto pYIN's 11.6 ms hop
@ 44.1 kHz before reconciliation. No torch, no librosa — trivial to test.
"""

from __future__ import annotations

from src.reconcile import PitchCandidate


def align_candidates(
    source: list[PitchCandidate],
    source_hop_seconds: float,
    target_frame_count: int,
    target_hop_seconds: float,
) -> list[PitchCandidate]:
    """Nearest-neighbor resample source candidates onto target timebase.

    We intentionally do NOT interpolate hz across frame boundaries — linear
    interpolation of pitch through an unvoiced -> voiced boundary would invent
    a fake transition. Nearest-neighbor preserves the voicing decision of
    the closest source frame.
    """
    if len(source) == 0:
        return [PitchCandidate(hz=None, confidence=0.0) for _ in range(target_frame_count)]

    last_idx = len(source) - 1
    out: list[PitchCandidate] = []
    for i in range(target_frame_count):
        t = i * target_hop_seconds
        j = round(t / source_hop_seconds)
        if j < 0:
            j = 0
        elif j > last_idx:
            j = last_idx
        out.append(source[j])
    return out
