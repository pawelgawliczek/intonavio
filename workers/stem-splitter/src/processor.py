"""End-to-end stem-split job orchestrator.

Pure-ish synchronous function — wired into the BullMQ worker by `worker.py`.
The Separator is injected so it stays loaded across jobs.
"""

from __future__ import annotations

import logging
import os
import tempfile
import time

from src.config import WorkerConfig
from src.db import (
    complete_stem_split,
    create_connection,
    mark_song_splitting,
    mark_variant_analyzing,
    mark_variant_splitting,
)
from src.logger import get_logger, log_with_context
from src.models import PitchAnalysisJobData, StemSplitJobData
from src.separator import StemSeparator
from src.storage import (
    create_s3_client,
    download_object,
    object_exists,
    upload_audio,
)
from src.youtube import download_audio

logger = get_logger(__name__)


def _read(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


async def process_stem_split_job(
    job_data: StemSplitJobData,
    config: WorkerConfig,
    separator: StemSeparator,
) -> None:
    """Run the full stem-split pipeline for one job.

    Writes outputs under `<stemsPrefix>/<stemType>.mp3` and updates the
    matching `SongVariant` row. Enqueues a pitch-analysis job tied to
    the same variant.
    """
    # Local import — keeps queue_producer module-load cost out of unit tests
    # that mock the orchestrator without bullmq installed.
    from src.queue_producer import enqueue_pitch_analysis

    trace_id = job_data.trace_id
    song_id = job_data.song_id
    variant_id = job_data.variant_id
    stems_prefix = job_data.stems_prefix
    start = time.monotonic()

    log_with_context(
        logger,
        logging.INFO,
        "Stem-split job started",
        traceId=trace_id,
        songId=song_id,
        variantId=variant_id,
        videoId=job_data.video_id,
    )

    s3 = create_s3_client(config)

    # 1. Mark Song + Variant SPLITTING (idempotent)
    conn = create_connection(config)
    try:
        mark_song_splitting(conn, song_id, trace_id)
        mark_variant_splitting(conn, variant_id, trace_id)
    finally:
        conn.close()

    full_key = f"{stems_prefix}/FULL.mp3"
    vocals_key = f"{stems_prefix}/VOCALS.mp3"
    other_key = f"{stems_prefix}/OTHER.mp3"

    with tempfile.TemporaryDirectory(prefix=f"stemsplit-{song_id}-") as work_dir:
        full_path = os.path.join(work_dir, "FULL.mp3")

        # 2. Source the FULL audio — reuse existing R2 object if present
        if object_exists(s3, config.r2_bucket_name, full_key):
            log_with_context(
                logger,
                logging.INFO,
                "FULL.mp3 already in R2, skipping YouTube download",
                traceId=trace_id,
                songId=song_id,
                key=full_key,
            )
            full_bytes = download_object(s3, config.r2_bucket_name, full_key, trace_id)
            with open(full_path, "wb") as f:
                f.write(full_bytes)
            full_size = len(full_bytes)
        else:
            full_path = download_audio(job_data.youtube_url, work_dir, trace_id)
            full_bytes = _read(full_path)
            full_size = len(full_bytes)
            upload_audio(s3, config.r2_bucket_name, full_key, full_bytes, trace_id)

        # 3. Separate
        vocals_path, instrumental_path = separator.separate(full_path, work_dir, trace_id)
        vocals_bytes = _read(vocals_path)
        other_bytes = _read(instrumental_path)

        # 4. Upload stems under the variant prefix
        upload_audio(s3, config.r2_bucket_name, vocals_key, vocals_bytes, trace_id)
        upload_audio(s3, config.r2_bucket_name, other_key, other_bytes, trace_id)

    # 5. Persist + transition state
    conn = create_connection(config)
    try:
        complete_stem_split(
            conn,
            song_id,
            [
                ("FULL", full_key, full_size),
                ("VOCALS", vocals_key, len(vocals_bytes)),
                ("OTHER", other_key, len(other_bytes)),
            ],
            trace_id,
        )
        mark_variant_analyzing(conn, variant_id, trace_id)
    finally:
        conn.close()

    # 6. Enqueue pitch analysis for this variant
    pitch_output_key = f"pitch/{song_id}/{variant_id}/reference.json"
    await enqueue_pitch_analysis(
        config,
        PitchAnalysisJobData(
            song_id=song_id,
            variant_id=variant_id,
            vocal_stem_key=vocals_key,
            pitch_output_key=pitch_output_key,
            trace_id=trace_id,
        ),
        trace_id,
    )

    log_with_context(
        logger,
        logging.INFO,
        "Stem-split job completed",
        traceId=trace_id,
        songId=song_id,
        variantId=variant_id,
        durationMs=int((time.monotonic() - start) * 1000),
    )
