"""One-time script to fix octave errors in all existing pitch data on R2.

Run inside the worker container:
    docker exec intonavio-worker-1 python -m scripts.fix_octave_errors_r2

Or locally with R2 credentials in env:
    python -m scripts.fix_octave_errors_r2
"""

import json
import logging
import math

import boto3
import numpy as np

from src.config import WorkerConfig

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger(__name__)

WINDOW_SIZE = 51
SEMITONE_THRESHOLD = 10.0


def hz_to_midi(hz: float) -> float:
    return 69.0 + 12.0 * math.log2(hz / 440.0)


def fix_frames(frames: list[dict]) -> int:
    """Fix octave errors in-place. Returns count of corrected frames."""
    midi_values = [
        f["midi"] if f["voiced"] and f["midi"] is not None else float("nan")
        for f in frames
    ]
    midi_arr = np.array(midi_values, dtype=np.float64)

    n = len(midi_arr)
    half_w = WINDOW_SIZE // 2
    fixed = 0

    for i in range(n):
        if np.isnan(midi_arr[i]):
            continue

        lo = max(0, i - half_w)
        hi = min(n, i + half_w + 1)
        window = midi_arr[lo:hi]
        voiced_in_window = window[~np.isnan(window)]

        if len(voiced_in_window) < 5:
            continue

        median = float(np.median(voiced_in_window))
        diff = midi_arr[i] - median
        f = frames[i]

        if diff > SEMITONE_THRESHOLD and f["hz"] is not None:
            f["hz"] = round(f["hz"] / 2, 1)
            f["midi"] = round(hz_to_midi(f["hz"]), 1)
            midi_arr[i] = f["midi"]
            fixed += 1
        elif diff < -SEMITONE_THRESHOLD and f["hz"] is not None:
            f["hz"] = round(f["hz"] * 2, 1)
            f["midi"] = round(hz_to_midi(f["hz"]), 1)
            midi_arr[i] = f["midi"]
            fixed += 1

    return fixed


def main() -> None:
    config = WorkerConfig()
    s3 = boto3.client(
        "s3",
        endpoint_url=f"https://{config.r2_account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=config.r2_access_key_id,
        aws_secret_access_key=config.r2_secret_access_key,
        region_name="auto",
    )

    paginator = s3.get_paginator("list_objects_v2")
    pages = paginator.paginate(Bucket=config.r2_bucket_name, Prefix="pitch/")

    for page in pages:
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if not key.endswith("/reference.json"):
                continue

            logger.info("Processing %s", key)
            response = s3.get_object(Bucket=config.r2_bucket_name, Key=key)
            data = json.loads(response["Body"].read())

            fixed = fix_frames(data["frames"])
            if fixed == 0:
                logger.info("  No octave errors found")
                continue

            logger.info("  Fixed %d frames, uploading", fixed)
            s3.put_object(
                Bucket=config.r2_bucket_name,
                Key=key,
                Body=json.dumps(data).encode("utf-8"),
                ContentType="application/json",
            )
            logger.info("  Done")


if __name__ == "__main__":
    main()
