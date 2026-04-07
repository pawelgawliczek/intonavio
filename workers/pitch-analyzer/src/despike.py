"""Single-frame outlier removal for reconciled pitch tracks.

After RMVPE reconciliation, residual single-frame jumps remain at note
boundaries and inside the disagree branches: a lone frame an octave (or a
few semitones) away from its neighbors. They render as thin vertical spikes
in the piano roll. We remove them with a tight median filter — pure
function, no torch.

Strategy: for each voiced frame, compare its MIDI value to the median of
its `window` neighbors (excluding itself, voiced only). If the deviation
exceeds `semitone_threshold`, replace hz with the median's hz (preserving
voicing). Frames near unvoiced boundaries with too few voiced neighbors
are left untouched — they're already on the edge and median is unreliable.
"""

from __future__ import annotations

import math

from src.models import PitchFrame


def _midi_from_hz(hz: float) -> float:
    return 69.0 + 12.0 * math.log2(hz / 440.0)


def _hz_from_midi(midi: float) -> float:
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def despike_frames(
    frames: list[PitchFrame],
    *,
    window: int = 5,
    semitone_threshold: float = 1.5,
) -> list[PitchFrame]:
    """Remove single-frame pitch outliers via local-median comparison.

    `window` is the half-width on each side, so each frame compares against
    up to 2*window neighbors. `semitone_threshold` is the minimum deviation
    (in semitones) that flags a frame as an outlier.
    """
    n = len(frames)
    if n == 0:
        return frames

    midis: list[float | None] = [
        _midi_from_hz(f.hz) if f.voiced and f.hz is not None else None for f in frames
    ]

    out: list[PitchFrame] = list(frames)
    for i in range(n):
        if midis[i] is None:
            continue

        lo = max(0, i - window)
        hi = min(n, i + window + 1)
        neighbors = [midis[j] for j in range(lo, hi) if j != i and midis[j] is not None]
        if len(neighbors) < 3:
            continue

        neighbors.sort()
        median = neighbors[len(neighbors) // 2]
        if abs(midis[i] - median) >= semitone_threshold:
            new_hz = _hz_from_midi(median)
            f = frames[i]
            out[i] = PitchFrame(
                t=f.t,
                hz=round(new_hz, 2),
                midi=round(median, 1),
                voiced=True,
                rms=f.rms,
            )
    return out
