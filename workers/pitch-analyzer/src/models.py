"""Pydantic models for job data, pitch output, and analysis stats."""

from pydantic import BaseModel, Field


class PitchAnalysisJobData(BaseModel):
    """Parses camelCase BullMQ job data from the NestJS producer.

    `variant_id` and `pitch_output_key` are optional for backwards
    compatibility with any legacy jobs still draining the queue. New
    jobs produced after the variant migration always set both.
    """

    song_id: str = Field(alias="songId")
    variant_id: str | None = Field(default=None, alias="variantId")
    vocal_stem_key: str = Field(alias="vocalStemKey")
    pitch_output_key: str | None = Field(default=None, alias="pitchOutputKey")
    trace_id: str = Field(alias="traceId")

    model_config = {"populate_by_name": True}


class PitchFrame(BaseModel):
    """Single frame of pitch analysis output."""

    t: float
    hz: float | None
    midi: float | None
    voiced: bool
    rms: float | None = None


class Phrase(BaseModel):
    """A contiguous run of voiced frames forming a singable phrase."""

    index: int
    start_frame: int = Field(serialization_alias="startFrame")
    end_frame: int = Field(serialization_alias="endFrame")
    start_time: float = Field(serialization_alias="startTime")
    end_time: float = Field(serialization_alias="endTime")
    voiced_frame_count: int = Field(serialization_alias="voicedFrameCount")

    model_config = {"populate_by_name": True}


class PitchAnalysisOutput(BaseModel):
    """Full pitch analysis result uploaded to R2 as JSON."""

    song_id: str = Field(serialization_alias="songId")
    sample_rate: int = Field(serialization_alias="sampleRate")
    hop_size: int = Field(serialization_alias="hopSize")
    hop_duration: float = Field(serialization_alias="hopDuration")
    frame_count: int = Field(serialization_alias="frameCount")
    frames: list[PitchFrame]
    phrases: list[Phrase]

    model_config = {"populate_by_name": True}


class AnalysisStats(BaseModel):
    """Internal statistics from pYIN extraction for validation and logging."""

    frame_count: int
    voiced_frame_count: int
    voiced_frame_percent: float
    frequency_min: float | None
    frequency_max: float | None
    is_valid: bool
