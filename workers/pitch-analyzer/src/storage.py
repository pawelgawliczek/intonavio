"""R2 upload/download operations via boto3."""

from __future__ import annotations

import logging
import time
from typing import TYPE_CHECKING, Any

import boto3

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


def download_stem(
    client: Any,
    bucket: str,
    key: str,
    trace_id: str,
) -> bytes:
    """Download a stem file from R2 and return raw bytes."""
    start = time.monotonic()
    response = client.get_object(Bucket=bucket, Key=key)
    data: bytes = response["Body"].read()
    duration_ms = int((time.monotonic() - start) * 1000)
    log_with_context(
        logger,
        logging.INFO,
        "Stem downloaded",
        traceId=trace_id,
        key=key,
        sizeBytes=len(data),
        durationMs=duration_ms,
    )
    return data


def upload_pitch_json(
    client: Any,
    bucket: str,
    key: str,
    json_bytes: bytes,
    trace_id: str,
) -> None:
    """Upload pitch analysis JSON to R2."""
    start = time.monotonic()
    client.put_object(
        Bucket=bucket,
        Key=key,
        Body=json_bytes,
        ContentType="application/json",
    )
    duration_ms = int((time.monotonic() - start) * 1000)
    log_with_context(
        logger,
        logging.INFO,
        "Pitch JSON uploaded",
        traceId=trace_id,
        key=key,
        sizeBytes=len(json_bytes),
        durationMs=duration_ms,
    )
