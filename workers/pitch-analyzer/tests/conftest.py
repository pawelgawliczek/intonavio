"""Shared test fixtures for pitch worker tests."""

import io
import struct
from typing import Any
from unittest.mock import MagicMock

import numpy as np
import pytest

from src.config import WorkerConfig


@pytest.fixture()
def sample_config() -> WorkerConfig:
    """WorkerConfig with test values (no real connections needed)."""
    return WorkerConfig(
        redis_url="redis://localhost:6379",
        database_url="postgresql://test:test@localhost:5432/test",
        r2_account_id="test-account",
        r2_access_key_id="test-key",
        r2_secret_access_key="test-secret",
        r2_bucket_name="test-bucket",
    )


def make_wav_bytes(frequency: float, duration: float, sample_rate: int = 44100) -> bytes:
    """Generate WAV file bytes containing a sine wave at the given frequency."""
    num_samples = int(sample_rate * duration)
    t = np.linspace(0, duration, num_samples, endpoint=False)
    samples = (np.sin(2 * np.pi * frequency * t) * 0.8).astype(np.float32)

    buf = io.BytesIO()
    num_channels = 1
    bits_per_sample = 32
    byte_rate = sample_rate * num_channels * bits_per_sample // 8
    block_align = num_channels * bits_per_sample // 8
    data_size = num_samples * block_align

    # WAV header
    buf.write(b"RIFF")
    buf.write(struct.pack("<I", 36 + data_size))
    buf.write(b"WAVE")
    buf.write(b"fmt ")
    buf.write(struct.pack("<I", 16))
    buf.write(struct.pack("<H", 3))  # IEEE float
    buf.write(struct.pack("<H", num_channels))
    buf.write(struct.pack("<I", sample_rate))
    buf.write(struct.pack("<I", byte_rate))
    buf.write(struct.pack("<H", block_align))
    buf.write(struct.pack("<H", bits_per_sample))
    buf.write(b"data")
    buf.write(struct.pack("<I", data_size))
    buf.write(samples.tobytes())

    return buf.getvalue()


@pytest.fixture()
def sine_440_bytes() -> bytes:
    """2 seconds of 440Hz sine wave as WAV."""
    return make_wav_bytes(440.0, 2.0)


@pytest.fixture()
def sine_261_bytes() -> bytes:
    """2 seconds of 261.63Hz (C4) sine wave as WAV."""
    return make_wav_bytes(261.63, 2.0)


@pytest.fixture()
def sine_1500_bytes() -> bytes:
    """2 seconds of 1500Hz sine wave as WAV (above vocal range)."""
    return make_wav_bytes(1500.0, 2.0)


@pytest.fixture()
def silence_bytes() -> bytes:
    """2 seconds of silence as WAV."""
    return make_wav_bytes(0.0, 2.0)


@pytest.fixture()
def mock_s3_client() -> MagicMock:
    """Mock S3 client for storage tests."""
    client: Any = MagicMock()
    return client


@pytest.fixture()
def mock_db_conn() -> MagicMock:
    """Mock psycopg2 connection for DB tests."""
    conn: Any = MagicMock()
    cursor = MagicMock()
    cursor.fetchone.return_value = ("test-pitch-data-id",)
    conn.cursor.return_value = cursor
    return conn
