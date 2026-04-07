"""Pydantic models for job data and stem-splitter outputs."""

from pydantic import BaseModel, Field


class StemSplitJobData(BaseModel):
    """Parses camelCase BullMQ job data from the NestJS producer.

    Mirrors `apps/api/src/jobs/interfaces/job-data.interface.ts#StemSplitJobData`.
    """

    song_id: str = Field(alias="songId")
    variant_id: str = Field(alias="variantId")
    source: str = "DRAFT"
    stems_prefix: str = Field(alias="stemsPrefix")
    video_id: str = Field(alias="videoId")
    youtube_url: str = Field(alias="youtubeUrl")
    trace_id: str = Field(alias="traceId")

    model_config = {"populate_by_name": True}


class PitchAnalysisJobData(BaseModel):
    """Job data we enqueue onto the pitch-analysis queue when separation finishes.

    Must serialize with camelCase aliases so the pitch-analyzer Python worker
    can read it.
    """

    song_id: str = Field(serialization_alias="songId")
    variant_id: str = Field(serialization_alias="variantId")
    vocal_stem_key: str = Field(serialization_alias="vocalStemKey")
    pitch_output_key: str = Field(serialization_alias="pitchOutputKey")
    trace_id: str = Field(serialization_alias="traceId")

    model_config = {"populate_by_name": True}


class StemArtifact(BaseModel):
    """One stem produced by separation, ready to upload to R2."""

    stem_type: str  # 'VOCALS' | 'OTHER' | 'FULL'
    storage_key: str
    audio_bytes: bytes
    file_size: int
