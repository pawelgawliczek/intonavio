"""Sentry SDK initialization and helpers for the pitch worker."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.config import WorkerConfig

logger = logging.getLogger(__name__)


def init_sentry(config: WorkerConfig) -> None:
    """Initialize Sentry SDK if a DSN is configured."""
    if not config.sentry_dsn:
        logger.info("Sentry disabled (no SENTRY_DSN)")
        return

    import sentry_sdk

    sentry_sdk.init(
        dsn=config.sentry_dsn,
        traces_sample_rate=0.1,
    )
    logger.info("Sentry initialized")


def capture_job_exception(
    exc: BaseException,
    trace_id: str,
    song_id: str,
) -> None:
    """Send a job exception to Sentry with context tags."""
    try:
        import sentry_sdk
    except ImportError:
        return

    if not sentry_sdk.is_initialized():
        return

    with sentry_sdk.new_scope() as scope:
        scope.set_tag("traceId", trace_id)
        scope.set_tag("songId", song_id)
        sentry_sdk.capture_exception(exc)
