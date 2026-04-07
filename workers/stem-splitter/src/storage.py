"""R2 upload/download/head operations via boto3."""

from __future__ import annotations

import logging
import time
from typing import TYPE_CHECKING, Any

import boto3
from botocore.exceptions import ClientError

from src.config import WorkerConfig
from src.logger import get_logger, log_with_context

if TYPE_CHECKING:
    from mypy_boto3_s3.client import S3Client

logger = get_logger(__name__)


def create_s3_client(config: WorkerConfig) -> S3Client:
    """Create a boto3 S3 client configured for Cloudflare R2."""
    return boto3.client(
        "s3",
        region_name="auto",
        endpoint_url=f"https://{config.r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=config.r2_access_key_id,
        aws_secret_access_key=config.r2_secret_access_key,
    )


def object_exists(client: Any, bucket: str, key: str) -> bool:
    """Return True iff the given key exists in R2."""
    try:
        client.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code")
        if code in ("404", "NoSuchKey", "NotFound"):
            return False
        raise


def download_object(client: Any, bucket: str, key: str, trace_id: str) -> bytes:
    """Download an object from R2 and return raw bytes."""
    start = time.monotonic()
    response = client.get_object(Bucket=bucket, Key=key)
    data: bytes = response["Body"].read()
    log_with_context(
        logger,
        logging.INFO,
        "Object downloaded",
        traceId=trace_id,
        key=key,
        sizeBytes=len(data),
        durationMs=int((time.monotonic() - start) * 1000),
    )
    return data


def upload_audio(
    client: Any,
    bucket: str,
    key: str,
    audio_bytes: bytes,
    trace_id: str,
) -> None:
    """Upload audio bytes (mp3) to R2 with the audio/mpeg content-type."""
    start = time.monotonic()
    client.put_object(Bucket=bucket, Key=key, Body=audio_bytes, ContentType="audio/mpeg")
    log_with_context(
        logger,
        logging.INFO,
        "Audio uploaded",
        traceId=trace_id,
        key=key,
        sizeBytes=len(audio_bytes),
        durationMs=int((time.monotonic() - start) * 1000),
    )
