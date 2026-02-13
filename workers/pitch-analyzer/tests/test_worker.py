"""Integration-style tests for the job orchestrator (all externals mocked)."""

from unittest.mock import MagicMock, patch

import pytest

from src.config import WorkerConfig
from src.models import AnalysisStats, PitchAnalysisJobData, PitchFrame
from src.worker import _process_job


@pytest.fixture()
def job_data() -> PitchAnalysisJobData:
    return PitchAnalysisJobData.model_validate(
        {
            "songId": "song-test",
            "vocalStemKey": "stems/song-test/VOCALS.mp3",
            "traceId": "pitch-song-test",
        }
    )


@pytest.fixture()
def config() -> WorkerConfig:
    return WorkerConfig(
        redis_url="redis://localhost:6379",
        database_url="postgresql://test:test@localhost:5432/test",
        r2_account_id="test-account",
        r2_access_key_id="test-key",
        r2_secret_access_key="test-secret",
        r2_bucket_name="test-bucket",
    )


def _mock_extract_pitch_success(
    audio_bytes: bytes,
    config: WorkerConfig,
    trace_id: str,
) -> tuple[list[PitchFrame], AnalysisStats]:
    frames = [PitchFrame(t=i * 0.01, hz=440.0, midi=69.0, voiced=True) for i in range(100)]
    stats = AnalysisStats(
        frame_count=100,
        voiced_frame_count=80,
        voiced_frame_percent=80.0,
        frequency_min=430.0,
        frequency_max=450.0,
        is_valid=True,
    )
    return frames, stats


def _mock_extract_pitch_invalid(
    audio_bytes: bytes,
    config: WorkerConfig,
    trace_id: str,
) -> tuple[list[PitchFrame], AnalysisStats]:
    frames = [PitchFrame(t=i * 0.01, hz=None, midi=None, voiced=False) for i in range(100)]
    stats = AnalysisStats(
        frame_count=100,
        voiced_frame_count=2,
        voiced_frame_percent=2.0,
        frequency_min=None,
        frequency_max=None,
        is_valid=True,
    )
    return frames, stats


@patch("src.worker.create_connection")
@patch("src.worker.upload_pitch_json")
@patch("src.worker.extract_pitch", side_effect=_mock_extract_pitch_success)
@patch("src.worker.download_stem", return_value=b"audio-data")
@patch("src.worker.create_s3_client")
def test_success_path(
    mock_s3: MagicMock,
    mock_download: MagicMock,
    mock_extract: MagicMock,
    mock_upload: MagicMock,
    mock_create_conn: MagicMock,
    job_data: PitchAnalysisJobData,
    config: WorkerConfig,
) -> None:
    """Happy path: download -> extract -> upload -> persist."""
    mock_conn = MagicMock()
    cursor = MagicMock()
    cursor.fetchone.return_value = ("pd-id",)
    mock_conn.cursor.return_value = cursor
    mock_create_conn.return_value = mock_conn

    _process_job(job_data, config)

    mock_download.assert_called_once()
    mock_extract.assert_called_once()
    mock_upload.assert_called_once()
    # Verify upload key format
    upload_args = mock_upload.call_args
    assert upload_args[0][2] == "pitch/song-test/reference.json"


@patch("src.worker.create_s3_client")
@patch("src.worker.download_stem", return_value=b"audio-data")
@patch("src.worker.extract_pitch", side_effect=_mock_extract_pitch_invalid)
def test_validation_failure_raises(
    mock_extract: MagicMock,
    mock_download: MagicMock,
    mock_s3: MagicMock,
    job_data: PitchAnalysisJobData,
    config: WorkerConfig,
) -> None:
    """Invalid pitch data raises ValueError for BullMQ retry."""
    with pytest.raises(ValueError, match="Pitch analysis invalid"):
        _process_job(job_data, config)


@patch("src.worker.create_s3_client")
@patch("src.worker.download_stem", side_effect=Exception("S3 connection failed"))
def test_s3_error_propagates(
    mock_download: MagicMock,
    mock_s3: MagicMock,
    job_data: PitchAnalysisJobData,
    config: WorkerConfig,
) -> None:
    """S3 download error propagates to caller."""
    with pytest.raises(Exception, match="S3 connection failed"):
        _process_job(job_data, config)


@patch("src.worker.create_connection")
@patch("src.worker.upload_pitch_json")
@patch("src.worker.extract_pitch", side_effect=_mock_extract_pitch_success)
@patch("src.worker.download_stem", return_value=b"audio-data")
@patch("src.worker.create_s3_client")
def test_db_error_propagates(
    mock_s3: MagicMock,
    mock_download: MagicMock,
    mock_extract: MagicMock,
    mock_upload: MagicMock,
    mock_create_conn: MagicMock,
    job_data: PitchAnalysisJobData,
    config: WorkerConfig,
) -> None:
    """DB error during persistence propagates."""
    mock_conn = MagicMock()
    cursor = MagicMock()
    cursor.execute.side_effect = Exception("DB connection lost")
    mock_conn.cursor.return_value = cursor
    mock_create_conn.return_value = mock_conn

    with pytest.raises(Exception, match="DB connection lost"):
        _process_job(job_data, config)


@patch("src.worker.create_connection")
@patch("src.worker.upload_pitch_json")
@patch("src.worker.extract_pitch", side_effect=_mock_extract_pitch_success)
@patch("src.worker.download_stem", return_value=b"audio-data")
@patch("src.worker.create_s3_client")
def test_camel_case_parsing(
    mock_s3: MagicMock,
    mock_download: MagicMock,
    mock_extract: MagicMock,
    mock_upload: MagicMock,
    mock_create_conn: MagicMock,
    config: WorkerConfig,
) -> None:
    """Job data with camelCase keys is parsed correctly."""
    mock_conn = MagicMock()
    cursor = MagicMock()
    cursor.fetchone.return_value = ("pd-id",)
    mock_conn.cursor.return_value = cursor
    mock_create_conn.return_value = mock_conn

    data = PitchAnalysisJobData.model_validate(
        {
            "songId": "camel-song",
            "vocalStemKey": "stems/camel-song/VOCALS.mp3",
            "traceId": "pitch-camel-song",
        }
    )

    _process_job(data, config)

    # Verify the correct stem key was used for download
    download_args = mock_download.call_args
    assert download_args[0][2] == "stems/camel-song/VOCALS.mp3"
