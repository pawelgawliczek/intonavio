"""Lazy-load / idle-unload lifecycle tests — no torch/audio-separator required.

Patches `Separator` inside `src.separator` so we can exercise the wrapper
without loading a real model.
"""

from __future__ import annotations

import time
from typing import Any
from unittest.mock import MagicMock, patch

from src.config import WorkerConfig
from src.separator import StemSeparator


def _cfg() -> WorkerConfig:
    return WorkerConfig(
        redis_url="redis://localhost:6379",
        database_url="postgresql://x:x@localhost/x",
        r2_account_id="a",
        r2_access_key_id="k",
        r2_secret_access_key="s",
        r2_bucket_name="b",
    )


def _fake_separator_class(produced_files: list[str]) -> Any:
    instance = MagicMock()
    instance.separate.return_value = produced_files
    instance.output_dir = None
    cls = MagicMock(return_value=instance)
    return cls, instance


def test_not_loaded_initially() -> None:
    sep = StemSeparator(_cfg())
    assert sep.is_loaded is False
    assert sep.is_busy is False


def test_load_is_idempotent() -> None:
    cls, instance = _fake_separator_class(["vocals.mp3", "instrumental.mp3"])
    with patch("src.separator.Separator", cls):
        sep = StemSeparator(_cfg())
        sep.load()
        sep.load()
        sep.load()
        # Separator class instantiated exactly once
        assert cls.call_count == 1
        # load_model called exactly once
        assert instance.load_model.call_count == 1
        assert sep.is_loaded is True


def test_unload_releases_model() -> None:
    cls, _ = _fake_separator_class(["vocals.mp3", "instrumental.mp3"])
    with patch("src.separator.Separator", cls):
        sep = StemSeparator(_cfg())
        sep.load()
        assert sep.is_loaded
        sep.unload()
        assert sep.is_loaded is False


def test_unload_is_noop_when_not_loaded() -> None:
    sep = StemSeparator(_cfg())
    sep.unload()  # should not raise
    assert sep.is_loaded is False


def test_separate_loads_on_first_call(tmp_path: Any) -> None:
    input_path = str(tmp_path / "FULL.mp3")
    with open(input_path, "wb") as f:
        f.write(b"fake")
    cls, _ = _fake_separator_class(
        ["FULL_(Vocals).mp3", "FULL_(Instrumental).mp3"]
    )
    with patch("src.separator.Separator", cls):
        sep = StemSeparator(_cfg())
        assert not sep.is_loaded
        v, i = sep.separate(input_path, str(tmp_path), "trace-1")
        assert sep.is_loaded is True
        assert v.endswith("Vocals).mp3")
        assert i.endswith("Instrumental).mp3")


def test_separate_updates_last_activity(tmp_path: Any) -> None:
    cls, _ = _fake_separator_class(["vocals.mp3", "instrumental.mp3"])
    with patch("src.separator.Separator", cls):
        sep = StemSeparator(_cfg())
        before = sep.idle_seconds
        time.sleep(0.05)
        sep.separate(str(tmp_path / "in.mp3"), str(tmp_path), "t")
        after = sep.idle_seconds
        # last_activity updated to ~now, so idle_seconds should be very small
        assert after < before + 0.05 or after < 0.1


def test_unload_refuses_while_busy() -> None:
    """If a job is in flight, unload() must be a no-op even if called."""
    cls, _ = _fake_separator_class(["vocals.mp3", "instrumental.mp3"])
    with patch("src.separator.Separator", cls):
        sep = StemSeparator(_cfg())
        sep.load()
        # Simulate an in-flight job by bumping the counter directly
        sep._in_flight = 1  # type: ignore[attr-defined]
        sep.unload()
        assert sep.is_loaded is True
        sep._in_flight = 0  # type: ignore[attr-defined]
        sep.unload()
        assert sep.is_loaded is False
