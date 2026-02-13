"""Tests for WorkerConfig environment validation."""

import pytest
from pydantic import ValidationError

from src.config import WorkerConfig


def test_config_loads_with_all_vars(monkeypatch: pytest.MonkeyPatch) -> None:
    """Config loads successfully when all required env vars are set."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@localhost/db")
    monkeypatch.setenv("R2_ACCOUNT_ID", "acc")
    monkeypatch.setenv("R2_ACCESS_KEY_ID", "key")
    monkeypatch.setenv("R2_SECRET_ACCESS_KEY", "secret")
    monkeypatch.setenv("R2_BUCKET_NAME", "bucket")

    config = WorkerConfig()
    assert config.redis_url == "redis://localhost:6379"
    assert config.queue_name == "pitch-analysis"


def test_config_missing_required_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    """Missing required env var raises ValidationError."""
    monkeypatch.delenv("REDIS_URL", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.delenv("R2_ACCOUNT_ID", raising=False)
    monkeypatch.delenv("R2_ACCESS_KEY_ID", raising=False)
    monkeypatch.delenv("R2_SECRET_ACCESS_KEY", raising=False)
    monkeypatch.delenv("R2_BUCKET_NAME", raising=False)

    with pytest.raises(ValidationError):
        WorkerConfig()


def test_config_defaults_correct(sample_config: WorkerConfig) -> None:
    """Default pYIN parameters match expected values."""
    assert sample_config.pyin_fmin == 65.0
    assert sample_config.pyin_fmax == 2093.0
    assert sample_config.pyin_hop_length == 512
    assert sample_config.pyin_sample_rate == 44100
    assert sample_config.max_unvoiced_ratio == 0.9
    assert sample_config.heartbeat_interval_seconds == 60
