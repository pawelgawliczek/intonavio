"""Wiring tests for the dark-launch RMVPE reconciliation in worker._process_job.

We never import torch here — `src.rmvpe_analyzer.load_rmvpe` /
`extract_rmvpe_candidates` are patched at the module level so the rmvpe
package is never touched.
"""

from unittest.mock import MagicMock, patch

import pytest

from src.config import WorkerConfig
from src.models import AnalysisStats, PitchAnalysisJobData, PitchFrame
from src.reconcile import PitchCandidate
from src.worker import _process_job


@pytest.fixture()
def job_data() -> PitchAnalysisJobData:
    return PitchAnalysisJobData.model_validate(
        {
            "songId": "song-rec",
            "vocalStemKey": "stems/song-rec/VOCALS.mp3",
            "traceId": "pitch-song-rec",
        }
    )


def _make_config(*, enable: bool) -> WorkerConfig:
    return WorkerConfig(
        redis_url="redis://localhost:6379",
        database_url="postgresql://test:test@localhost:5432/test",
        r2_account_id="test-account",
        r2_access_key_id="test-key",
        r2_secret_access_key="test-secret",
        r2_bucket_name="test-bucket",
        enable_rmvpe_reconcile=enable,
    )


def _mock_extract_pitch(
    audio_bytes: bytes,
    config: WorkerConfig,
    trace_id: str,
) -> tuple[list[PitchFrame], AnalysisStats]:
    frames = [PitchFrame(t=i * 0.01, hz=440.0, midi=69.0, voiced=True, rms=0.1) for i in range(10)]
    stats = AnalysisStats(
        frame_count=10,
        voiced_frame_count=10,
        voiced_frame_percent=100.0,
        frequency_min=440.0,
        frequency_max=440.0,
        is_valid=True,
    )
    return frames, stats


def _make_db_mock() -> MagicMock:
    mock_conn = MagicMock()
    cursor = MagicMock()
    cursor.fetchone.return_value = ("pd-id",)
    mock_conn.cursor.return_value = cursor
    return mock_conn


@patch("src.worker.create_connection")
@patch("src.worker.upload_pitch_json")
@patch("src.worker.extract_pitch", side_effect=_mock_extract_pitch)
@patch("src.worker.download_stem", return_value=b"audio-data")
@patch("src.worker.create_s3_client")
def test_flag_off_skips_rmvpe(
    mock_s3: MagicMock,
    mock_download: MagicMock,
    mock_extract: MagicMock,
    mock_upload: MagicMock,
    mock_create_conn: MagicMock,
    job_data: PitchAnalysisJobData,
) -> None:
    """Flag OFF: only the vocal stem is downloaded, no RMVPE module touched."""
    mock_create_conn.return_value = _make_db_mock()

    # If anything tried to import rmvpe_analyzer.load_rmvpe, this patch would
    # capture it. Assert it's never called.
    with patch("src.rmvpe_analyzer.load_rmvpe") as mock_load:
        _process_job(job_data, _make_config(enable=False))

    assert mock_load.call_count == 0
    # Only one download call — the vocal stem.
    assert mock_download.call_count == 1
    assert mock_download.call_args_list[0][0][2] == "stems/song-rec/VOCALS.mp3"


@patch("src.worker.create_connection")
@patch("src.worker.upload_pitch_json")
@patch("src.worker.extract_pitch", side_effect=_mock_extract_pitch)
@patch("src.worker.download_stem", return_value=b"audio-data")
@patch("src.worker.create_s3_client")
def test_flag_on_downloads_full_mix_and_replaces_frames(
    mock_s3: MagicMock,
    mock_download: MagicMock,
    mock_extract: MagicMock,
    mock_upload: MagicMock,
    mock_create_conn: MagicMock,
    job_data: PitchAnalysisJobData,
) -> None:
    """Flag ON: full mix is downloaded from FULL.mp3 sibling key, RMVPE runs,
    frames are replaced via reconcile."""
    mock_create_conn.return_value = _make_db_mock()

    # RMVPE returns 10 voiced frames at 220 Hz (one octave below pYIN's 440).
    # That's 12 semitones apart -> reconcile picks higher-confidence tracker.
    # pYIN cands are confidence 1.0; RMVPE cands here are confidence 1.0 too,
    # so the tie breaks toward RMVPE -> final hz should be 220.
    rmvpe_cands = [PitchCandidate(hz=220.0, confidence=1.0) for _ in range(10)]

    with (
        patch("src.rmvpe_analyzer.load_rmvpe", return_value=MagicMock()) as mock_load,
        patch(
            "src.rmvpe_analyzer.extract_rmvpe_candidates", return_value=rmvpe_cands
        ) as mock_extract_rmvpe,
    ):
        _process_job(job_data, _make_config(enable=True))

    # Two downloads: vocal stem then full mix
    assert mock_download.call_count == 2
    keys = [call.args[2] for call in mock_download.call_args_list]
    assert keys == ["stems/song-rec/VOCALS.mp3", "stems/song-rec/FULL.mp3"]

    mock_load.assert_called_once()
    mock_extract_rmvpe.assert_called_once()

    # Verify upload happened with replaced frames — frames inside the uploaded
    # JSON should reflect 220 Hz, not 440.
    upload_args = mock_upload.call_args
    json_bytes = upload_args[0][3]
    body = json_bytes.decode("utf-8")
    assert '"hz":220' in body
    assert '"hz":440' not in body
