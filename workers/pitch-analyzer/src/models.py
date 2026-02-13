"""Pydantic models for job data, pitch output, and analysis stats."""

from pydantic import BaseModel, Field


class PitchAnalysisJobData(BaseModel):
    """Parses camelCase BullMQ job data from the NestJS producer."""

    song_id: str = Field(alias="songId")
    vocal_stem_key: str = Field(alias="vocalStemKey")
    trace_id: str = Field(alias="traceId")

    model_config = {"populate_by_name": True}


class PitchFrame(BaseModel):
    """Single frame of pitch analysis output."""

    t: float
    hz: float | None
    midi: float | None
    voiced: bool


class PitchAnalysisOutput(BaseModel):
    """Full pitch analysis result uploaded to R2 as JSON."""

    song_id: str = Field(serialization_alias="songId")
    sample_rate: int = Field(serialization_alias="sampleRate")
    hop_size: int = Field(serialization_alias="hopSize")
    hop_duration: float = Field(serialization_alias="hopDuration")
    frame_count: int = Field(serialization_alias="frameCount")
    frames: list[PitchFrame]

    model_config = {"populate_by_name": True}


class AnalysisStats(BaseModel):
    """Internal statistics from pYIN extraction for validation and logging."""

    frame_count: int
    voiced_frame_count: int
    voiced_frame_percent: float
    frequency_min: float | None
    frequency_max: float | None
    is_valid: bool
