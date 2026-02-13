"""BullMQ worker wrapper with heartbeat for pitch analysis jobs."""

from __future__ import annotations

import asyncio
import contextlib
import logging
from typing import TYPE_CHECKING, Any

from bullmq import Worker

from src.logger import get_logger, log_with_context

if TYPE_CHECKING:
    from collections.abc import Awaitable, Callable

    from bullmq import Job

    from src.config import WorkerConfig

logger = get_logger(__name__)


async def run_heartbeat(
    config: WorkerConfig,
    stop_event: asyncio.Event,
) -> None:
    """Log a heartbeat every N seconds until stop_event is set."""
    while not stop_event.is_set():
        log_with_context(logger, logging.INFO, "heartbeat", status="alive")
        with contextlib.suppress(TimeoutError):
            await asyncio.wait_for(
                stop_event.wait(),
                timeout=config.heartbeat_interval_seconds,
            )


async def create_worker(
    config: WorkerConfig,
    handler: Callable[[Job[Any], str | None], Awaitable[Any]],
) -> Worker:
    """Create a BullMQ worker listening on the pitch-analysis queue."""
    worker = Worker(
        config.queue_name,
        handler,
        {"connection": config.redis_url, "lockDuration": config.lock_duration_ms},
    )
    log_with_context(
        logger,
        logging.INFO,
        "Worker started",
        queue=config.queue_name,
    )
    return worker
