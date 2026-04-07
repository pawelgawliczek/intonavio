"""Enqueue downstream pitch-analysis jobs onto the BullMQ queue.

Uses the Python `bullmq` package's Queue.add() — same Lua scripts as the
NestJS BullMQ producer, so jobs are interchangeable. Job name (`'analyze'`)
and options must match `apps/api/src/jobs/jobs.service.ts#enqueuePitchAnalysis`
so the existing pitch-analyzer worker picks them up identically.
"""

from __future__ import annotations

import logging

from bullmq import Queue

from src.config import WorkerConfig
from src.logger import get_logger, log_with_context
from src.models import PitchAnalysisJobData

logger = get_logger(__name__)

PITCH_ANALYSIS_QUEUE_NAME = "pitch-analysis"
PITCH_ANALYSIS_JOB_NAME = "analyze"

# Mirror RETRY_OPTIONS in apps/api/src/jobs/jobs.service.ts
PITCH_ANALYSIS_JOB_OPTS = {
    "attempts": 3,
    "backoff": {"type": "exponential", "delay": 5000},
    "removeOnComplete": True,
    "removeOnFail": False,
}


async def enqueue_pitch_analysis(
    config: WorkerConfig,
    data: PitchAnalysisJobData,
    trace_id: str,
) -> str:
    """Enqueue an `analyze` job onto the `pitch-analysis` BullMQ queue.

    Opens a fresh Queue connection, adds the job, then closes — keeping the
    surface area small (no long-lived producer state).
    """
    queue = Queue(
        PITCH_ANALYSIS_QUEUE_NAME,
        {"connection": config.redis_url},
    )
    try:
        payload = data.model_dump(by_alias=True)
        job = await queue.add(PITCH_ANALYSIS_JOB_NAME, payload, PITCH_ANALYSIS_JOB_OPTS)
        log_with_context(
            logger,
            logging.INFO,
            "Pitch analysis job enqueued",
            traceId=trace_id,
            songId=data.song_id,
            jobId=job.id,
        )
        return str(job.id) if job.id is not None else ""
    finally:
        await queue.close()
