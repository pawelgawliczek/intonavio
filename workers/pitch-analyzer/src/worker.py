"""Pitch analysis job orchestrator and main entry point."""

from __future__ import annotations

import asyncio
import logging
import signal
import time
from concurrent.futures import ThreadPoolExecutor
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from bullmq import Job

from src.analyzer import extract_pitch, validate_analysis
from src.config import WorkerConfig
from src.consumer import create_worker, run_heartbeat
from src.db import complete_pitch_analysis, create_connection, mark_song_failed
from src.logger import get_logger, log_with_context
from src.models import PitchAnalysisJobData, PitchAnalysisOutput, PitchFrame
from src.phrases import detect_phrases
from src.sentry_setup import capture_job_exception, init_sentry
from src.storage import create_s3_client, download_stem, upload_pitch_json

logger = get_logger(__name__)
executor = ThreadPoolExecutor(max_workers=1)


def _process_job(job_data: PitchAnalysisJobData, config: WorkerConfig) -> None:
    """Synchronous job handler — runs in a thread to avoid blocking the event loop."""
    trace_id = job_data.trace_id
    song_id = job_data.song_id
    start = time.monotonic()

    log_with_context(
        logger,
        logging.INFO,
        "Job started",
        traceId=trace_id,
        songId=song_id,
    )

    s3 = create_s3_client(config)

    # 1. Download vocal stem from R2
    audio_bytes = download_stem(s3, config.r2_bucket_name, job_data.vocal_stem_key, trace_id)

    # 2. Run pYIN extraction
    frames, stats = extract_pitch(audio_bytes, config, trace_id)

    # 2b. Optional: RMVPE second-opinion reconciliation (Phase C, dark-launch).
    if config.enable_rmvpe_reconcile:
        from src.analyzer import compute_stats, hz_to_midi
        from src.frame_align import align_candidates
        from src.reconcile import PitchCandidate, reconcile_tracks
        from src.rmvpe_analyzer import (
            RMVPE_HOP_SECONDS,
            extract_rmvpe_candidates,
            load_rmvpe,
        )

        # Derive full-mix key from the vocal stem key:
        #   stems/<song>/VOCALS.mp3 -> stems/<song>/FULL.mp3
        full_key = job_data.vocal_stem_key.rsplit("/", 1)[0] + "/FULL.mp3"
        full_bytes = download_stem(s3, config.r2_bucket_name, full_key, trace_id)

        rmvpe = load_rmvpe(f"{config.rmvpe_model_dir}/rmvpe.pt")
        rmvpe_cands = extract_rmvpe_candidates(rmvpe, full_bytes)

        # Rebuild pYIN candidates from persisted frames. analyzer.build_frames
        # already demoted sub-threshold frames to unvoiced; reconcile's threshold
        # gate still fires via pyin_voiced_thresh.
        pyin_cands = [PitchCandidate(hz=f.hz, confidence=1.0 if f.voiced else 0.0) for f in frames]

        pyin_hop = config.pyin_hop_length / config.pyin_sample_rate
        aligned_rmvpe = align_candidates(rmvpe_cands, RMVPE_HOP_SECONDS, len(pyin_cands), pyin_hop)

        reconciled = reconcile_tracks(
            pyin_cands,
            aligned_rmvpe,
            pyin_voiced_thresh=config.pyin_voiced_prob_thresh,
            rmvpe_voiced_thresh=config.rmvpe_voiced_thresh,
            agreement_semitones=config.reconcile_agreement_semitones,
        )

        # Post-reconcile guard: RMVPE runs on the FULL mix and will happily
        # track instrument pitches during sections where the singer is silent
        # (intros, instrumental breaks). If a frame came in via the
        # rmvpe_only branch and has no pYIN-voiced anchor within ±500 ms,
        # it's almost certainly an instrument — demote it to unvoiced.
        import math as _math

        from src.reconcile import ReconciledFrame

        anchor_window = max(1, int(0.5 / pyin_hop))
        max_anchor_semitones = 7.0  # > perfect-fifth from nearest vocal anchor → instrument
        pyin_anchor_hz: list[float | None] = [
            c.hz if (c.hz is not None and c.confidence >= config.pyin_voiced_prob_thresh) else None
            for c in pyin_cands
        ]

        def nearest_anchor_hz(idx: int) -> float | None:
            for d in range(0, anchor_window + 1):
                for j in (idx - d, idx + d) if d > 0 else (idx,):
                    if 0 <= j < len(pyin_anchor_hz) and pyin_anchor_hz[j] is not None:
                        return pyin_anchor_hz[j]
            return None

        guarded: list[ReconciledFrame] = []
        for i, r in enumerate(reconciled):
            if r.source == "rmvpe_only" and r.voiced and r.hz is not None:
                anchor = nearest_anchor_hz(i)
                if anchor is None:
                    guarded.append(
                        ReconciledFrame(hz=None, voiced=False, source="rmvpe_only_orphan")
                    )
                    continue
                dist = abs(12.0 * _math.log2(r.hz / anchor))
                if dist > max_anchor_semitones:
                    guarded.append(
                        ReconciledFrame(hz=None, voiced=False, source="rmvpe_only_far")
                    )
                    continue
            guarded.append(r)
        reconciled = guarded

        new_frames: list[PitchFrame] = []
        branch_counts: dict[str, int] = {}
        for f, r in zip(frames, reconciled, strict=True):
            branch_counts[r.source] = branch_counts.get(r.source, 0) + 1
            if r.voiced and r.hz is not None:
                new_frames.append(
                    PitchFrame(
                        t=f.t,
                        hz=r.hz,
                        midi=round(hz_to_midi(r.hz), 1),
                        voiced=True,
                        rms=f.rms,
                    )
                )
            else:
                new_frames.append(PitchFrame(t=f.t, hz=None, midi=None, voiced=False, rms=f.rms))

        from src.despike import despike_frames

        frames = despike_frames(new_frames)
        stats = compute_stats(frames)

        log_with_context(
            logger,
            logging.INFO,
            "RMVPE reconciliation complete",
            traceId=trace_id,
            songId=song_id,
            branchCounts=branch_counts,
            voicedFramePercent=stats.voiced_frame_percent,
        )

        # Free RMVPE model after each job — idle cost is high (~500MB).
        del rmvpe
        import gc

        gc.collect()

    # 3. Validate — raise if invalid so BullMQ retries
    if not validate_analysis(stats, config.max_unvoiced_ratio):
        raise ValueError(
            f"Pitch analysis invalid: {stats.voiced_frame_percent}% voiced "
            f"(threshold: {(1 - config.max_unvoiced_ratio) * 100}% minimum)"
        )

    # 4. Build output and serialize to camelCase JSON
    hop_duration = config.pyin_hop_length / config.pyin_sample_rate
    phrases = detect_phrases(frames, hop_duration)
    output = PitchAnalysisOutput(
        song_id=song_id,
        sample_rate=config.pyin_sample_rate,
        hop_size=config.pyin_hop_length,
        hop_duration=hop_duration,
        frame_count=stats.frame_count,
        frames=frames,
        phrases=phrases,
    )
    json_bytes = output.model_dump_json(by_alias=True).encode("utf-8")

    # 5. Upload to R2
    storage_key = f"pitch/{song_id}/reference.json"
    upload_pitch_json(s3, config.r2_bucket_name, storage_key, json_bytes, trace_id)

    # 6. Persist to DB and mark song READY
    conn = create_connection(config)
    try:
        complete_pitch_analysis(
            conn,
            song_id,
            storage_key,
            stats.frame_count,
            hop_duration,
            trace_id,
        )
    finally:
        conn.close()

    duration_ms = int((time.monotonic() - start) * 1000)
    log_with_context(
        logger,
        logging.INFO,
        "Job completed",
        traceId=trace_id,
        songId=song_id,
        durationMs=duration_ms,
    )


async def handle_job(job: Job[Any], token: str | None = None) -> None:
    """Async entry point called by BullMQ Worker — offloads CPU work to a thread."""
    config = WorkerConfig()
    job_data = PitchAnalysisJobData.model_validate(job.data)

    loop = asyncio.get_running_loop()
    try:
        await loop.run_in_executor(executor, _process_job, job_data, config)
    except Exception as exc:
        capture_job_exception(exc, job_data.trace_id, job_data.song_id)
        log_with_context(
            logger,
            logging.ERROR,
            "Job failed",
            traceId=job_data.trace_id,
            songId=job_data.song_id,
            error=str(exc),
        )
        # Mark song as FAILED on final attempt (attempt 3 = last)
        attempt = getattr(job, "attemptsMade", 0)
        max_attempts = 3
        if attempt >= max_attempts:
            try:
                conn = create_connection(config)
                try:
                    mark_song_failed(
                        conn,
                        job_data.song_id,
                        str(exc),
                        job_data.trace_id,
                    )
                finally:
                    conn.close()
            except Exception as db_err:
                log_with_context(
                    logger,
                    logging.ERROR,
                    "Failed to mark song as FAILED",
                    traceId=job_data.trace_id,
                    songId=job_data.song_id,
                    error=str(db_err),
                )
        raise


async def main() -> None:
    """Start the worker, heartbeat, and wait for shutdown signal."""
    config = WorkerConfig()
    init_sentry(config)
    stop_event = asyncio.Event()

    log_with_context(
        logger,
        logging.INFO,
        "Pitch worker starting",
        queue=config.queue_name,
        redisUrl=config.redis_url.split("@")[-1] if "@" in config.redis_url else "***",
    )

    worker = await create_worker(config, handle_job)
    heartbeat_task = asyncio.create_task(run_heartbeat(config, stop_event))

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop_event.set)

    await stop_event.wait()

    log_with_context(logger, logging.INFO, "Shutting down")
    await worker.close()
    heartbeat_task.cancel()


if __name__ == "__main__":
    asyncio.run(main())
