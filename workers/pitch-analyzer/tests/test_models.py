"""Tests for Pydantic models."""

import json

import pytest
from pydantic import ValidationError

from src.models import AnalysisStats, PitchAnalysisJobData, PitchAnalysisOutput, PitchFrame


def test_job_data_parses_camel_case() -> None:
    """PitchAnalysisJobData parses camelCase keys from BullMQ."""
    data = PitchAnalysisJobData.model_validate(
        {
            "songId": "song-123",
            "vocalStemKey": "stems/song-123/VOCALS.mp3",
            "traceId": "pitch-song-123",
        }
    )
    assert data.song_id == "song-123"
    assert data.vocal_stem_key == "stems/song-123/VOCALS.mp3"
    assert data.trace_id == "pitch-song-123"


def test_job_data_missing_field_raises() -> None:
    """Missing required field raises ValidationError."""
    with pytest.raises(ValidationError):
        PitchAnalysisJobData.model_validate({"songId": "song-123"})


def test_output_serializes_to_camel_case() -> None:
    """PitchAnalysisOutput serializes to camelCase JSON."""
    output = PitchAnalysisOutput(
        song_id="song-1",
        sample_rate=44100,
        hop_size=512,
        hop_duration=0.01161,
        frame_count=1,
        frames=[PitchFrame(t=0.0, hz=440.0, midi=69.0, voiced=True)],
        phrases=[],
    )
    data = json.loads(output.model_dump_json(by_alias=True))
    assert "songId" in data
    assert "sampleRate" in data
    assert "hopSize" in data
    assert "hopDuration" in data
    assert "frameCount" in data
    assert "phrases" in data
    assert data["frames"][0]["hz"] == 440.0


def test_pitch_frame_unvoiced() -> None:
    """Unvoiced PitchFrame has None for hz and midi."""
    frame = PitchFrame(t=0.0, hz=None, midi=None, voiced=False)
    assert frame.hz is None
    assert frame.midi is None
    assert frame.voiced is False


def test_analysis_stats_schema() -> None:
    """AnalysisStats can represent both valid and invalid states."""
    valid = AnalysisStats(
        frame_count=100,
        voiced_frame_count=80,
        voiced_frame_percent=80.0,
        frequency_min=200.0,
        frequency_max=500.0,
        is_valid=True,
    )
    assert valid.is_valid
    assert valid.voiced_frame_percent == 80.0


def test_job_data_extra_fields_ignored() -> None:
    """Extra fields in job data don't cause errors."""
    data = PitchAnalysisJobData.model_validate(
        {
            "songId": "song-123",
            "vocalStemKey": "stems/song-123/VOCALS.mp3",
            "traceId": "pitch-song-123",
            "extraField": "ignored",
        }
    )
    assert data.song_id == "song-123"
