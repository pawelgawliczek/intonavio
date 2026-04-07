"""Sentry initialization and job-scoped exception capture."""

import sentry_sdk

from src.config import WorkerConfig


def init_sentry(config: WorkerConfig) -> None:
    """Initialize Sentry SDK if SENTRY_DSN is set, otherwise no-op."""
    if not config.sentry_dsn:
        return
    sentry_sdk.init(
        dsn=config.sentry_dsn,
        traces_sample_rate=0.0,
        send_default_pii=False,
    )


def capture_job_exception(exc: BaseException, trace_id: str, song_id: str) -> None:
    """Capture an exception with job context tags."""
    with sentry_sdk.push_scope() as scope:
        scope.set_tag("traceId", trace_id)
        scope.set_tag("songId", song_id)
        scope.set_tag("service", "stem-splitter")
        sentry_sdk.capture_exception(exc)
