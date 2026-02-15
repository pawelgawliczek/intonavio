"""Tests for phrase detection algorithm."""

from src.models import PitchFrame
from src.phrases import detect_phrases

HOP = 0.0116  # ~86 frames/second, typical pYIN hop


def _voiced(t: float, rms: float = 0.05) -> PitchFrame:
    return PitchFrame(t=t, hz=440.0, midi=69.0, voiced=True, rms=rms)


def _unvoiced(t: float, rms: float = 0.0) -> PitchFrame:
    return PitchFrame(t=t, hz=None, midi=None, voiced=False, rms=rms)


class TestAllVoiced:
    def test_single_phrase(self):
        frames = [_voiced(i * HOP) for i in range(100)]
        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 1
        assert phrases[0].index == 0
        assert phrases[0].start_frame == 0
        assert phrases[0].end_frame == 99
        assert phrases[0].voiced_frame_count == 100


class TestSingleGap:
    def test_gap_splits_into_two_phrases(self):
        # 50 voiced, 30 unvoiced (>0.3s gap), 50 voiced
        voiced_a = [_voiced(i * HOP) for i in range(50)]
        gap = [_unvoiced((50 + i) * HOP) for i in range(30)]
        voiced_b = [_voiced((80 + i) * HOP) for i in range(50)]
        frames = voiced_a + gap + voiced_b

        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 2
        assert phrases[0].index == 0
        assert phrases[1].index == 1
        assert phrases[0].end_frame < phrases[1].start_frame


class TestShortPhraseMerged:
    def test_short_phrase_merged_with_neighbor(self):
        # 50 voiced, 30 unvoiced gap, 3 voiced (too short), 30 unvoiced gap, 50 voiced
        voiced_a = [_voiced(i * HOP) for i in range(50)]
        gap1 = [_unvoiced((50 + i) * HOP) for i in range(30)]
        short = [_voiced((80 + i) * HOP) for i in range(3)]
        gap2 = [_unvoiced((83 + i) * HOP) for i in range(30)]
        voiced_b = [_voiced((113 + i) * HOP) for i in range(50)]
        frames = voiced_a + gap1 + short + gap2 + voiced_b

        phrases = detect_phrases(frames, HOP)
        # Short phrase (3 frames ~0.035s < 0.5s min) should be merged
        assert len(phrases) == 2


class TestAllUnvoiced:
    def test_zero_phrases(self):
        frames = [_unvoiced(i * HOP) for i in range(100)]
        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 0


class TestGapBelowThreshold:
    def test_no_split(self):
        # 50 voiced, 10 unvoiced (~0.116s < 0.3s threshold), 50 voiced
        voiced_a = [_voiced(i * HOP) for i in range(50)]
        gap = [_unvoiced((50 + i) * HOP) for i in range(10)]
        voiced_b = [_voiced((60 + i) * HOP) for i in range(50)]
        frames = voiced_a + gap + voiced_b

        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 1


class TestEmptyFrames:
    def test_zero_phrases(self):
        phrases = detect_phrases([], HOP)
        assert len(phrases) == 0


class TestLowRmsVoicedFrames:
    def test_low_rms_treated_as_gap(self):
        # Voiced frames with RMS below threshold act as silence
        voiced_a = [_voiced(i * HOP, rms=0.05) for i in range(50)]
        low_rms = [_voiced((50 + i) * HOP, rms=0.001) for i in range(30)]
        voiced_b = [_voiced((80 + i) * HOP, rms=0.05) for i in range(50)]
        frames = voiced_a + low_rms + voiced_b

        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 2


class TestPhraseTimestamps:
    def test_start_end_times(self):
        frames = [_voiced(i * HOP) for i in range(50)]
        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 1
        assert phrases[0].start_time == round(0 * HOP, 6)
        assert phrases[0].end_time == round(49 * HOP, 6)


class TestReindexing:
    def test_consecutive_indices(self):
        voiced_a = [_voiced(i * HOP) for i in range(50)]
        gap = [_unvoiced((50 + i) * HOP) for i in range(30)]
        voiced_b = [_voiced((80 + i) * HOP) for i in range(50)]
        gap2 = [_unvoiced((130 + i) * HOP) for i in range(30)]
        voiced_c = [_voiced((160 + i) * HOP) for i in range(50)]
        frames = voiced_a + gap + voiced_b + gap2 + voiced_c

        phrases = detect_phrases(frames, HOP)
        assert len(phrases) == 3
        for i, phrase in enumerate(phrases):
            assert phrase.index == i
