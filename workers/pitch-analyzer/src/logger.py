"""Structured JSON logger for the pitch worker."""

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any


class JsonFormatter(logging.Formatter):
    """Emits JSON log lines to stdout with mandatory fields."""

    def format(self, record: logging.LogRecord) -> str:
        entry: dict[str, Any] = {
            "level": record.levelname.lower(),
            "timestamp": datetime.now(UTC).isoformat(),
            "service": "pitch-worker",
            "module": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "extra_fields"):
            entry.update(record.extra_fields)
        if record.exc_info and record.exc_info[1] is not None:
            entry["error"] = {
                "type": type(record.exc_info[1]).__name__,
                "message": str(record.exc_info[1]),
            }
        return json.dumps(entry, default=str)


def get_logger(name: str) -> logging.Logger:
    """Create a logger with JSON formatting on stdout."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger


def log_with_context(
    logger: logging.Logger,
    level: int,
    message: str,
    **kwargs: Any,
) -> None:
    """Log a message with extra context fields merged as top-level JSON keys."""
    extra = {"extra_fields": kwargs}
    logger.log(level, message, extra=extra)
