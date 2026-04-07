"""Unit tests for src.frame_align.align_candidates."""

from src.frame_align import align_candidates
from src.reconcile import PitchCandidate


def _voiced(hz: float) -> PitchCandidate:
    return PitchCandidate(hz=hz, confidence=1.0)


def _unvoiced() -> PitchCandidate:
    return PitchCandidate(hz=None, confidence=0.0)


def test_empty_source_returns_unvoiced_target() -> None:
    out = align_candidates([], 0.01, 5, 0.02)
    assert len(out) == 5
    assert all(c.hz is None and c.confidence == 0.0 for c in out)


def test_same_timebase_passthrough() -> None:
    src = [_voiced(100.0), _voiced(200.0), _voiced(300.0)]
    out = align_candidates(src, 0.01, 3, 0.01)
    assert [c.hz for c in out] == [100.0, 200.0, 300.0]


def test_upsampling_picks_nearest() -> None:
    # source @ 20 ms hop, target @ 10 ms hop — each source frame should
    # repeat ~twice on the finer grid.
    src = [_voiced(100.0), _voiced(200.0), _voiced(300.0)]
    out = align_candidates(src, 0.02, 6, 0.01)
    # i=0 t=0     -> j=0
    # i=1 t=0.01  -> round(0.5)=0
    # i=2 t=0.02  -> j=1
    # i=3 t=0.03  -> round(1.5)=2 (banker's: round() uses banker's rounding)
    # Just assert nearest-neighbor monotonicity & endpoints rather than exact tie-break.
    assert out[0].hz == 100.0
    assert out[2].hz == 200.0
    assert out[-1].hz == 300.0


def test_downsampling_picks_nearest() -> None:
    src = [_voiced(float(i * 10)) for i in range(1, 11)]  # 10 frames @ 10 ms
    out = align_candidates(src, 0.01, 3, 0.05)  # 3 frames @ 50 ms
    # i=0 t=0    -> j=0  -> 10
    # i=1 t=0.05 -> j=5  -> 60
    # i=2 t=0.10 -> j=10 -> clamp to 9 -> 100
    assert [c.hz for c in out] == [10.0, 60.0, 100.0]


def test_endpoint_clamping_past_end() -> None:
    src = [_voiced(100.0), _voiced(200.0)]
    out = align_candidates(src, 0.01, 5, 0.01)
    # frames 2,3,4 all clamp to last source
    assert out[-1].hz == 200.0
    assert out[-2].hz == 200.0
    assert out[-3].hz == 200.0


def test_preserves_unvoiced_decisions() -> None:
    src = [_voiced(100.0), _unvoiced(), _voiced(300.0)]
    out = align_candidates(src, 0.01, 3, 0.01)
    assert out[0].hz == 100.0
    assert out[1].hz is None
    assert out[2].hz == 300.0
