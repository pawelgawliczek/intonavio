"""Tests for R2 storage adapter (mocked boto3)."""

from unittest.mock import MagicMock, patch

import pytest

from src.config import WorkerConfig
from src.storage import create_s3_client, download_stem, upload_pitch_json


def test_create_s3_client_endpoint(sample_config: WorkerConfig) -> None:
    """S3 client uses correct R2 endpoint URL."""
    with patch("src.storage.boto3.client") as mock_client:
        create_s3_client(sample_config)
        mock_client.assert_called_once_with(
            "s3",
            region_name="auto",
            endpoint_url=f"https://{sample_config.r2_account_id}.r2.cloudflarestorage.com",
            aws_access_key_id=sample_config.r2_access_key_id,
            aws_secret_access_key=sample_config.r2_secret_access_key,
        )


def test_download_stem_success(mock_s3_client: MagicMock) -> None:
    """Download returns raw bytes from S3 response body."""
    body_mock = MagicMock()
    body_mock.read.return_value = b"audio-data"
    mock_s3_client.get_object.return_value = {"Body": body_mock}

    result = download_stem(mock_s3_client, "bucket", "stems/s1/VOCALS.mp3", "trace-1")

    assert result == b"audio-data"
    mock_s3_client.get_object.assert_called_once_with(
        Bucket="bucket",
        Key="stems/s1/VOCALS.mp3",
    )


def test_download_stem_not_found(mock_s3_client: MagicMock) -> None:
    """S3 error propagates as-is."""
    mock_s3_client.get_object.side_effect = Exception("NoSuchKey")

    with pytest.raises(Exception, match="NoSuchKey"):
        download_stem(mock_s3_client, "bucket", "missing-key", "trace-1")


def test_upload_pitch_json_content_type(mock_s3_client: MagicMock) -> None:
    """Upload sets Content-Type to application/json."""
    upload_pitch_json(
        mock_s3_client,
        "bucket",
        "pitch/s1/reference.json",
        b'{"frames":[]}',
        "trace-1",
    )

    mock_s3_client.put_object.assert_called_once_with(
        Bucket="bucket",
        Key="pitch/s1/reference.json",
        Body=b'{"frames":[]}',
        ContentType="application/json",
    )


def test_upload_correct_key(mock_s3_client: MagicMock) -> None:
    """Upload uses the exact key provided."""
    upload_pitch_json(
        mock_s3_client,
        "my-bucket",
        "pitch/song-abc/reference.json",
        b"{}",
        "trace-1",
    )

    call_kwargs = mock_s3_client.put_object.call_args.kwargs
    assert call_kwargs["Key"] == "pitch/song-abc/reference.json"
    assert call_kwargs["Bucket"] == "my-bucket"
