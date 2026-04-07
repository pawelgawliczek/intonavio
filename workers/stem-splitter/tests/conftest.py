"""Shared pytest fixtures for stem-splitter tests."""

from __future__ import annotations

import pytest

from src.config import WorkerConfig


@pytest.fixture
def worker_config() -> WorkerConfig:
    return WorkerConfig(
        redis_url="redis://localhost:6379",
        database_url="postgresql://postgres:postgres@localhost:5432/test",
        r2_account_id="acct",
        r2_access_key_id="key",
        r2_secret_access_key="secret",
        r2_bucket_name="bucket",
    )
