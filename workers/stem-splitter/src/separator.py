"""BS-Roformer separation wrapper around audio-separator.

Lazy model loading: the model is NOT loaded at worker startup. Instead it
loads on the first job (~5s) and unloads after an idle window (see
`config.idle_unload_seconds`). This keeps the container's resident memory
at ~200 MB when no jobs are in flight, vs ~3-4 GB with the model resident.
"""

from __future__ import annotations

import gc
import logging
import os
import shutil
import threading
import time

from audio_separator.separator import Separator

from src.config import WorkerConfig
from src.logger import get_logger, log_with_context

logger = get_logger(__name__)


class StemSeparator:
    """Lazy-loaded audio-separator wrapper — thread-safe load/unload."""

    def __init__(self, config: WorkerConfig) -> None:
        self._config = config
        self._sep: Separator | None = None
        self._lock = threading.Lock()
        self._last_activity: float = time.monotonic()
        self._in_flight: int = 0  # concurrent job count (always 0 or 1 today)

    @property
    def is_loaded(self) -> bool:
        return self._sep is not None

    @property
    def is_busy(self) -> bool:
        return self._in_flight > 0

    @property
    def idle_seconds(self) -> float:
        return time.monotonic() - self._last_activity

    def load(self) -> None:
        """Instantiate Separator and load the model. Idempotent — safe to call per job."""
        with self._lock:
            if self._sep is not None:
                return
            start = time.monotonic()
            sep = Separator(
                output_dir=None,
                output_format="mp3",
                log_level=logging.WARNING,
                model_file_dir=self._config.model_dir,
            )
            sep.load_model(model_filename=self._config.model_file)
            self._sep = sep
            log_with_context(
                logger,
                logging.INFO,
                "BS-Roformer model loaded",
                model=self._config.model_file,
                durationMs=int((time.monotonic() - start) * 1000),
            )

    def unload(self) -> None:
        """Release the loaded model and reclaim memory. Safe to call when idle."""
        with self._lock:
            if self._sep is None:
                return
            if self._in_flight > 0:
                # Someone started a job between the idle check and here; abort.
                return
            self._sep = None
        gc.collect()
        log_with_context(
            logger,
            logging.INFO,
            "BS-Roformer model unloaded (idle)",
            idleSeconds=round(self.idle_seconds, 1),
        )

    def separate(self, input_path: str, output_dir: str, trace_id: str) -> tuple[str, str]:
        """Run separation. Loads the model on first call if not already loaded.

        Returns `(vocals_path, instrumental_path)`.
        """
        self.load()
        with self._lock:
            self._in_flight += 1
        try:
            assert self._sep is not None  # noqa: S101 — load() just ensured this
            os.makedirs(output_dir, exist_ok=True)
            self._sep.output_dir = output_dir

            # audio-separator caches its output path at init time and ignores
            # both the output_dir property and cwd changes. Belt-and-suspenders:
            # chdir AND post-hoc relocate files that land in the wrong place.
            previous_cwd = os.getcwd()
            os.chdir(output_dir)
            try:
                start = time.monotonic()
                produced = self._sep.separate(input_path)
            finally:
                os.chdir(previous_cwd)
            log_with_context(
                logger,
                logging.INFO,
                "Separation finished",
                traceId=trace_id,
                inputPath=input_path,
                outputs=produced,
                durationMs=int((time.monotonic() - start) * 1000),
            )

            vocals_path: str | None = None
            instrumental_path: str | None = None
            for filename in produced:
                full = filename if os.path.isabs(filename) else os.path.join(output_dir, filename)
                # If the file isn't where expected, check the original cwd (library fallback)
                if not os.path.exists(full):
                    fallback = os.path.join(previous_cwd, os.path.basename(filename))
                    if os.path.exists(fallback):
                        shutil.move(fallback, full)
                        log_with_context(
                            logger,
                            logging.WARNING,
                            "Relocated stem from cwd fallback",
                            traceId=trace_id,
                            src=fallback,
                            dst=full,
                        )
                lower = filename.lower()
                if "vocals" in lower:
                    vocals_path = full
                elif "instrumental" in lower or "no_vocals" in lower or "other" in lower:
                    instrumental_path = full

            if vocals_path is None or instrumental_path is None:
                raise RuntimeError(
                    f"Could not identify vocals + instrumental in separator outputs: {produced}"
                )

            return vocals_path, instrumental_path
        finally:
            with self._lock:
                self._in_flight -= 1
                self._last_activity = time.monotonic()
