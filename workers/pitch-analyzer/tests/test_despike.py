"""Tests for despike_frames — single-frame outlier removal."""

from __future__ import annotations

from src.despike import despike_frames
from src.models import PitchFrame


def _f(hz: float | None, t: float = 0.0) -> PitchFrame:
    if hz is None:
        return PitchFrame(t=t, hz=None, midi=None, voiced=False, rms=None)
    midi = 69.0 + 12.0 * (hz / 440.0 - 1.0)  # rough; tests don't depend on exact midi
    return PitchFrame(t=t, hz=hz, midi=round(midi, 1), voiced=True, rms=None)


def test_empty_returns_empty() -> None:
    assert despike_frames([]) == []


def test_clean_run_unchanged() -> None:
    frames = [_f(440.0, t=i * 0.01) for i in range(10)]
    out = despike_frames(frames)
    assert [round(f.hz or 0, 2) for f in out] == [440.0] * 10


def test_single_octave_spike_is_pulled_down() -> None:
    frames = [_f(440.0, t=i * 0.01) for i in range(10)]
    frames[5] = _f(880.0, t=0.05)  # one-octave spike
    out = despike_frames(frames)
    assert out[5].hz is not None
    # geometric mean of 440 and 440 → 440
    assert abs(out[5].hz - 440.0) < 1.0


def test_spike_between_two_different_pitches_is_midpoint() -> None:
    # Stable run at 440, then a spike, then stable run at 880.
    # geometric mean(440, 880) = sqrt(387200) ≈ 622.25 (≈ D#5, halfway in semis).
    frames = [_f(440.0, t=i * 0.01) for i in range(5)]
    frames.append(_f(220.0, t=0.05))  # outlier
    frames += [_f(880.0, t=(6 + i) * 0.01) for i in range(5)]
    out = despike_frames(frames)
    assert out[5].hz is not None
    assert 620.0 < out[5].hz < 625.0


def test_small_jitter_below_threshold_kept() -> None:
    # 1 semitone deviation, threshold 1.5 → kept
    frames = [_f(440.0, t=i * 0.01) for i in range(10)]
    frames[5] = _f(466.16, t=0.05)  # ~1 semi up
    out = despike_frames(frames)
    assert out[5].hz is not None
    assert abs(out[5].hz - 466.16) < 0.5


def test_unvoiced_neighbors_skip() -> None:
    # Frame 5 surrounded by unvoiced — too few neighbors → untouched
    frames = [_f(None) for _ in range(10)]
    frames[5] = _f(880.0, t=0.05)
    out = despike_frames(frames)
    assert out[5].hz == 880.0


def test_unvoiced_frame_untouched() -> None:
    frames = [_f(440.0, t=i * 0.01) for i in range(10)]
    frames[5] = _f(None, t=0.05)
    out = despike_frames(frames)
    assert out[5].voiced is False
    assert out[5].hz is None
