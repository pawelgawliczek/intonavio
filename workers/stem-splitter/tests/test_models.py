"""Pydantic model parsing/serialization tests."""

import pytest

from src.models import PitchAnalysisJobData, StemSplitJobData


class TestStemSplitJobData:
    def test_parses_camelcase_from_nestjs(self) -> None:
        raw = {
            "songId": "song-123",
            "videoId": "vid-abc",
            "youtubeUrl": "https://youtu.be/abc",
            "traceId": "trace-xyz",
        }
        parsed = StemSplitJobData.model_validate(raw)
        assert parsed.song_id == "song-123"
        assert parsed.video_id == "vid-abc"
        assert parsed.youtube_url == "https://youtu.be/abc"
        assert parsed.trace_id == "trace-xyz"

    def test_rejects_missing_fields(self) -> None:
        with pytest.raises(ValueError):
            StemSplitJobData.model_validate({"songId": "s"})


class TestPitchAnalysisJobData:
    def test_serializes_to_camelcase(self) -> None:
        data = PitchAnalysisJobData(
            song_id="song-123",
            vocal_stem_key="stems/song-123/VOCALS.mp3",
            trace_id="trace-xyz",
        )
        payload = data.model_dump(by_alias=True)
        assert payload == {
            "songId": "song-123",
            "vocalStemKey": "stems/song-123/VOCALS.mp3",
            "traceId": "trace-xyz",
        }
