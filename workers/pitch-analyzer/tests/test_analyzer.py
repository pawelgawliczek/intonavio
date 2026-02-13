"""Core algorithmic tests for pYIN extraction pipeline — target 95% branch coverage."""

import math

import numpy as np

from src.analyzer import (
    build_frames,
    compute_stats,
    extract_pitch,
    hz_to_midi,
    validate_analysis,
)
from src.config import WorkerConfig
from src.models import AnalysisStats, PitchFrame

# --- hz_to_midi ---


def test_hz_to_midi_440hz() -> None:
    """440 Hz is MIDI note 69 (A4)."""
    assert hz_to_midi(440.0) == 69.0


def test_hz_to_midi_261_63hz() -> None:
    """261.63 Hz is approximately MIDI note 60 (C4)."""
    assert abs(hz_to_midi(261.63) - 60.0) < 0.02


def test_hz_to_midi_329_63hz() -> None:
    """329.63 Hz is approximately MIDI note 64 (E4)."""
    assert abs(hz_to_midi(329.63) - 64.0) < 0.02


def test_hz_to_midi_880hz() -> None:
    """880 Hz is MIDI note 81 (A5)."""
    assert hz_to_midi(880.0) == 81.0


# --- extract_pitch with real audio ---


def test_extract_pitch_440hz_sine(
    sine_440_bytes: bytes,
    sample_config: WorkerConfig,
) -> None:
    """440Hz sine wave detected with voiced frames near 440Hz."""
    frames, stats = extract_pitch(sine_440_bytes, sample_config, "test-trace")

    voiced = [f for f in frames if f.voiced and f.hz is not None]
    assert len(voiced) > 0

    for f in voiced:
        assert f.hz is not None
        assert abs(f.hz - 440.0) < 5.0  # within 5Hz tolerance for pYIN


def test_extract_pitch_261hz_sine(
    sine_261_bytes: bytes,
    sample_config: WorkerConfig,
) -> None:
    """261.63Hz (C4) sine wave detected within tolerance."""
    frames, stats = extract_pitch(sine_261_bytes, sample_config, "test-trace")

    voiced = [f for f in frames if f.voiced and f.hz is not None]
    assert len(voiced) > 0

    for f in voiced:
        assert f.hz is not None
        assert abs(f.hz - 261.63) < 5.0


def test_extract_pitch_silence(
    silence_bytes: bytes,
    sample_config: WorkerConfig,
) -> None:
    """Silence produces all unvoiced frames."""
    frames, stats = extract_pitch(silence_bytes, sample_config, "test-trace")

    # Silence should produce very few or no voiced frames
    assert stats.voiced_frame_percent < 10.0


def test_extract_pitch_frame_count(
    sine_440_bytes: bytes,
    sample_config: WorkerConfig,
) -> None:
    """Frame count matches expected value for 2s audio."""
    frames, stats = extract_pitch(sine_440_bytes, sample_config, "test-trace")

    expected = math.ceil(2.0 * 44100 / 512)
    # Allow some tolerance due to librosa padding behavior
    assert abs(stats.frame_count - expected) <= 2


# --- build_frames ---


def test_build_frames_with_nan() -> None:
    """NaN f0 values produce unvoiced frames."""
    f0 = np.array([440.0, np.nan, 261.63])
    voiced = np.array([True, False, True])

    frames = build_frames(f0, voiced, 44100, 512)

    assert frames[0].voiced is True
    assert frames[0].hz == 440.0
    assert frames[1].voiced is False
    assert frames[1].hz is None
    assert frames[2].voiced is True


def test_build_frames_time_monotonic() -> None:
    """Frame t values are monotonically increasing."""
    f0 = np.array([440.0, 440.0, 440.0, 440.0, 440.0])
    voiced = np.array([True, True, True, True, True])

    frames = build_frames(f0, voiced, 44100, 512)

    for i in range(1, len(frames)):
        assert frames[i].t > frames[i - 1].t


def test_build_frames_voiced_flag_false_overrides_f0() -> None:
    """If voiced_flag is False, frame is unvoiced even if f0 has a value."""
    f0 = np.array([440.0])
    voiced = np.array([False])

    frames = build_frames(f0, voiced, 44100, 512)
    assert frames[0].voiced is False
    assert frames[0].hz is None


# --- compute_stats ---


def test_compute_stats_all_voiced() -> None:
    """100% voiced frames."""
    frames = [PitchFrame(t=i * 0.01, hz=440.0, midi=69.0, voiced=True) for i in range(100)]
    stats = compute_stats(frames)

    assert stats.voiced_frame_count == 100
    assert stats.voiced_frame_percent == 100.0
    assert stats.frequency_min == 440.0
    assert stats.frequency_max == 440.0


def test_compute_stats_all_unvoiced() -> None:
    """0% voiced frames."""
    frames = [PitchFrame(t=i * 0.01, hz=None, midi=None, voiced=False) for i in range(100)]
    stats = compute_stats(frames)

    assert stats.voiced_frame_count == 0
    assert stats.voiced_frame_percent == 0.0
    assert stats.frequency_min is None
    assert stats.frequency_max is None


def test_compute_stats_mixed() -> None:
    """50% voiced frames."""
    frames = [
        PitchFrame(t=0.0, hz=200.0, midi=55.0, voiced=True),
        PitchFrame(t=0.01, hz=None, midi=None, voiced=False),
        PitchFrame(t=0.02, hz=500.0, midi=71.0, voiced=True),
        PitchFrame(t=0.03, hz=None, midi=None, voiced=False),
    ]
    stats = compute_stats(frames)

    assert stats.voiced_frame_count == 2
    assert stats.voiced_frame_percent == 50.0
    assert stats.frequency_min == 200.0
    assert stats.frequency_max == 500.0


def test_compute_stats_empty() -> None:
    """Empty frame list."""
    stats = compute_stats([])
    assert stats.frame_count == 0
    assert stats.is_valid is False


# --- validate_analysis ---


def test_validate_analysis_valid() -> None:
    """50% voiced with 0.9 threshold passes."""
    stats = AnalysisStats(
        frame_count=100,
        voiced_frame_count=50,
        voiced_frame_percent=50.0,
        frequency_min=200.0,
        frequency_max=500.0,
        is_valid=True,
    )
    assert validate_analysis(stats, 0.9) is True


def test_validate_analysis_rejected() -> None:
    """5% voiced exceeds 0.9 unvoiced threshold."""
    stats = AnalysisStats(
        frame_count=100,
        voiced_frame_count=5,
        voiced_frame_percent=5.0,
        frequency_min=200.0,
        frequency_max=500.0,
        is_valid=True,
    )
    assert validate_analysis(stats, 0.9) is False


def test_validate_analysis_empty() -> None:
    """0 frames always fails."""
    stats = AnalysisStats(
        frame_count=0,
        voiced_frame_count=0,
        voiced_frame_percent=0.0,
        frequency_min=None,
        frequency_max=None,
        is_valid=False,
    )
    assert validate_analysis(stats, 0.9) is False


def test_extract_pitch_idempotent(
    sine_440_bytes: bytes,
    sample_config: WorkerConfig,
) -> None:
    """Same input produces identical output on two runs."""
    frames1, stats1 = extract_pitch(sine_440_bytes, sample_config, "trace-1")
    frames2, stats2 = extract_pitch(sine_440_bytes, sample_config, "trace-2")

    assert stats1.frame_count == stats2.frame_count
    assert stats1.voiced_frame_count == stats2.voiced_frame_count
    for f1, f2 in zip(frames1, frames2, strict=True):
        assert f1.t == f2.t
        assert f1.hz == f2.hz
        assert f1.voiced == f2.voiced
