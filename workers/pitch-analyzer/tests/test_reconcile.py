"""Exhaustive unit tests for the reconcile module — all 4+ branches."""

from __future__ import annotations

import math

import pytest

from src.reconcile import (
    PitchCandidate,
    reconcile_frame,
    reconcile_tracks,
)

# Thresholds reused across cases (match WorkerConfig defaults).
PYIN_THRESH = 0.8
RMVPE_THRESH = 0.5
AGREEMENT_SEMI = 0.5


def _pyin(hz: float | None, conf: float) -> PitchCandidate:
    return PitchCandidate(hz=hz, confidence=conf)


def _rmvpe(hz: float | None, conf: float) -> PitchCandidate:
    return PitchCandidate(hz=hz, confidence=conf)


def _reconcile(p: PitchCandidate, r: PitchCandidate):
    return reconcile_frame(
        p,
        r,
        pyin_voiced_thresh=PYIN_THRESH,
        rmvpe_voiced_thresh=RMVPE_THRESH,
        agreement_semitones=AGREEMENT_SEMI,
    )


# ── Branch 1: both unvoiced ───────────────────────────────────────────────

class TestBothUnvoiced:
    def test_both_none(self) -> None:
        out = _reconcile(_pyin(None, 0.0), _rmvpe(None, 0.0))
        assert out.voiced is False
        assert out.hz is None
        assert out.source == "unvoiced"

    def test_both_below_thresh_even_if_hz_present(self) -> None:
        # pYIN emits an hz but with confidence below threshold → untrusted
        out = _reconcile(_pyin(220.0, 0.5), _rmvpe(221.0, 0.3))
        assert out.voiced is False
        assert out.source == "unvoiced"


# ── Branch 2: both voiced, agree → log-weighted mean ──────────────────────

class TestBothVoicedAgree:
    def test_identical_pitch_is_same(self) -> None:
        out = _reconcile(_pyin(440.0, 0.9), _rmvpe(440.0, 0.8))
        assert out.voiced is True
        assert out.source == "agree"
        assert out.hz == pytest.approx(440.0, rel=1e-6)

    def test_small_disagreement_produces_weighted_geometric_mean(self) -> None:
        # pYIN says 440 Hz @ 0.9; RMVPE says 445 Hz @ 0.7 (≈20 cents apart).
        out = _reconcile(_pyin(440.0, 0.9), _rmvpe(445.0, 0.7))
        assert out.voiced is True
        assert out.source == "agree"
        expected = math.exp((0.9 * math.log(440.0) + 0.7 * math.log(445.0)) / (0.9 + 0.7))
        assert out.hz == pytest.approx(expected, rel=1e-9)
        # Sanity: the blended value sits between the two inputs, closer to pYIN.
        assert 440.0 < out.hz < 445.0
        assert abs(out.hz - 440.0) < abs(out.hz - 445.0)


# ── Branch 3: both voiced, disagree ≥ threshold → higher-confidence wins ──

class TestBothVoicedDisagree:
    def test_one_octave_up_pyin_higher_conf(self) -> None:
        # pYIN @ 220, RMVPE stuck at 440 (octave error). pYIN more confident.
        out = _reconcile(_pyin(220.0, 0.95), _rmvpe(440.0, 0.6))
        assert out.voiced is True
        assert out.source == "disagree_pyin"
        assert out.hz == 220.0

    def test_one_octave_down_rmvpe_higher_conf(self) -> None:
        # pYIN fell to subharmonic 110, RMVPE holds 220 w/ higher conf.
        out = _reconcile(_pyin(110.0, 0.85), _rmvpe(220.0, 0.92))
        assert out.voiced is True
        assert out.source == "disagree_rmvpe"
        assert out.hz == 220.0

    def test_tie_breaks_toward_rmvpe(self) -> None:
        out = _reconcile(_pyin(220.0, 0.85), _rmvpe(440.0, 0.85))
        assert out.source == "disagree_rmvpe"
        assert out.hz == 440.0

    def test_just_over_agreement_threshold_triggers_disagreement(self) -> None:
        # 60 cents apart = 0.6 semitones > 0.5 → disagreement branch
        out = _reconcile(_pyin(440.0, 0.9), _rmvpe(455.4, 0.95))
        assert out.source == "disagree_rmvpe"


# ── Branch 4: exactly one voiced ──────────────────────────────────────────

class TestSingleTrackerVoiced:
    def test_only_pyin_trusted(self) -> None:
        out = _reconcile(_pyin(330.0, 0.95), _rmvpe(None, 0.0))
        assert out.voiced is True
        assert out.source == "pyin_only"
        assert out.hz == 330.0

    def test_only_rmvpe_trusted(self) -> None:
        out = _reconcile(_pyin(None, 0.0), _rmvpe(330.0, 0.9))
        assert out.voiced is True
        assert out.source == "rmvpe_only"
        assert out.hz == 330.0

    def test_pyin_voiced_but_below_thresh_falls_back_to_rmvpe(self) -> None:
        # pYIN has hz but conf 0.6 < 0.8 → untrusted. RMVPE 0.7 ≥ 0.5 → trusted.
        out = _reconcile(_pyin(440.0, 0.6), _rmvpe(445.0, 0.7))
        assert out.voiced is True
        assert out.source == "rmvpe_only"

    def test_pyin_low_conf_and_rmvpe_unvoiced_yields_unvoiced(self) -> None:
        out = _reconcile(_pyin(440.0, 0.6), _rmvpe(None, 0.0))
        assert out.voiced is False
        assert out.source == "unvoiced"


# ── reconcile_tracks wrapper ──────────────────────────────────────────────

class TestReconcileTracks:
    def test_length_mismatch_raises(self) -> None:
        with pytest.raises(ValueError, match="Frame count mismatch"):
            reconcile_tracks(
                [_pyin(440.0, 0.9)],
                [_rmvpe(440.0, 0.9), _rmvpe(440.0, 0.9)],
                pyin_voiced_thresh=PYIN_THRESH,
                rmvpe_voiced_thresh=RMVPE_THRESH,
                agreement_semitones=AGREEMENT_SEMI,
            )

    def test_mixed_frame_sequence(self) -> None:
        pyin = [
            _pyin(None, 0.0),        # both unvoiced
            _pyin(440.0, 0.9),       # agree
            _pyin(220.0, 0.95),      # disagree, pYIN wins
            _pyin(None, 0.0),        # rmvpe_only
            _pyin(440.0, 0.6),       # pYIN low-conf, rmvpe unvoiced → unvoiced
        ]
        rmvpe = [
            _rmvpe(None, 0.0),
            _rmvpe(440.5, 0.8),
            _rmvpe(440.0, 0.6),
            _rmvpe(330.0, 0.9),
            _rmvpe(None, 0.0),
        ]
        out = reconcile_tracks(
            pyin,
            rmvpe,
            pyin_voiced_thresh=PYIN_THRESH,
            rmvpe_voiced_thresh=RMVPE_THRESH,
            agreement_semitones=AGREEMENT_SEMI,
        )
        assert [f.source for f in out] == [
            "unvoiced",
            "agree",
            "disagree_pyin",
            "rmvpe_only",
            "unvoiced",
        ]
        assert [f.voiced for f in out] == [False, True, True, True, False]
