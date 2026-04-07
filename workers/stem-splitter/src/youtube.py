"""yt-dlp wrapper — downloads the best audio track for a YouTube URL."""

from __future__ import annotations

import logging
import os
import time

from yt_dlp import YoutubeDL

from src.logger import get_logger, log_with_context

logger = get_logger(__name__)


def download_audio(youtube_url: str, output_dir: str, trace_id: str) -> str:
    """Download YouTube audio to `output_dir`, return absolute path to the resulting mp3.

    Uses yt-dlp's best-audio + ffmpeg post-processor to write a 192kbps mp3.
    """
    start = time.monotonic()
    output_template = os.path.join(output_dir, "FULL.%(ext)s")
    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }
        ],
    }
    with YoutubeDL(ydl_opts) as ydl:
        ydl.download([youtube_url])

    final_path = os.path.join(output_dir, "FULL.mp3")
    if not os.path.exists(final_path):
        raise FileNotFoundError(f"yt-dlp did not produce expected file: {final_path}")

    log_with_context(
        logger,
        logging.INFO,
        "YouTube audio downloaded",
        traceId=trace_id,
        url=youtube_url,
        path=final_path,
        sizeBytes=os.path.getsize(final_path),
        durationMs=int((time.monotonic() - start) * 1000),
    )
    return final_path
