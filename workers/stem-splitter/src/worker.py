"""Stem-splitter worker entry point.

Loads BS-Roformer once at startup, then consumes jobs from the BullMQ
`stem-split` queue. The Separator is shared across all jobs to amortize
model load. CPU-bound work runs in a thread to avoid blocking the asyncio
event loop that BullMQ + Redis use.
"""

from __future__ import annotations

import asyncio
import logging
import signal
from concurrent.futures import ThreadPoolExecutor
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from bullmq import Job

from src.config import WorkerConfig
from src.consumer import create_worker, run_heartbeat
from src.db import create_connection, mark_song_failed
from src.logger import get_logger, log_with_context
from src.models import StemSplitJobData
from src.processor import process_stem_split_job
from src.sentry_setup import capture_job_exception, init_sentry
from src.separator import StemSeparator

logger = get_logger(__name__)
executor = ThreadPoolExecutor(max_workers=1)

# Module-level singletons populated in main(), referenced by handle_job.
_config: WorkerConfig | None = None
_separator: StemSeparator | None = None


def _run_pipeline_sync(job_data: StemSplitJobData) -> None:
    """Bridge async processor onto a worker thread.

    BS-Roformer separation is CPU-heavy and would otherwise starve the
    asyncio loop that BullMQ uses for redis IO and lock renewals.
    """
    assert _config is not None and _separator is not None
    asyncio.run(process_stem_split_job(job_data, _config, _separator))


async def handle_job(job: Job[Any], token: str | None = None) -> None:
    """Async entry point called by BullMQ Worker."""
    assert _config is not None
    job_data = StemSplitJobData.model_validate(job.data)

    loop = asyncio.get_running_loop()
    try:
        await loop.run_in_executor(executor, _run_pipeline_sync, job_data)
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
        attempt = getattr(job, "attemptsMade", 0)
        max_attempts = 3
        if attempt >= max_attempts:
            try:
                conn = create_connection(_config)
                try:
                    mark_song_failed(conn, job_data.song_id, str(exc), job_data.trace_id)
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


async def run_idle_unloader(
    separator: StemSeparator,
    config: WorkerConfig,
    stop_event: asyncio.Event,
) -> None:
    """Background task — unload the model after idle_unload_seconds of no activity."""
    check_interval = max(30, config.idle_unload_seconds // 4)
    while not stop_event.is_set():
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=check_interval)
        except TimeoutError:
            pass
        if stop_event.is_set():
            return
        if (
            separator.is_loaded
            and not separator.is_busy
            and separator.idle_seconds >= config.idle_unload_seconds
        ):
            separator.unload()


async def main() -> None:
    """Start the worker, heartbeat, and wait for shutdown signal.

    The BS-Roformer model is NOT loaded here — it loads lazily on the first
    job and unloads after `idle_unload_seconds` of no activity. See
    `src/separator.py` for rationale.
    """
    global _config, _separator

    _config = WorkerConfig()
    init_sentry(_config)

    log_with_context(
        logger,
        logging.INFO,
        "Stem-splitter worker starting",
        queue=_config.queue_name,
        idleUnloadSeconds=_config.idle_unload_seconds,
    )

    _separator = StemSeparator(_config)

    stop_event = asyncio.Event()
    worker = await create_worker(_config, handle_job)
    heartbeat_task = asyncio.create_task(run_heartbeat(_config, stop_event))
    unloader_task = asyncio.create_task(run_idle_unloader(_separator, _config, stop_event))

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, stop_event.set)

    await stop_event.wait()

    log_with_context(logger, logging.INFO, "Shutting down")
    await worker.close()
    heartbeat_task.cancel()
    unloader_task.cancel()


if __name__ == "__main__":
    asyncio.run(main())
