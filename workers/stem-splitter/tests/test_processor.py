"""Orchestration tests — mock external deps, verify pipeline flow + skip-if-exists path."""

from __future__ import annotations

import asyncio
from typing import Any
from unittest.mock import MagicMock, patch

from src.config import WorkerConfig
from src.models import StemSplitJobData


def _job() -> StemSplitJobData:
    return StemSplitJobData(
        song_id="song-1",
        variant_id="sv-1",
        source="DRAFT",
        stems_prefix="stems/song-1/DRAFT",
        video_id="vid",
        youtube_url="https://youtu.be/x",
        trace_id="trace-1",
    )


def _write_stubs(tmp_dir: str) -> tuple[str, str, str]:
    import os

    full = os.path.join(tmp_dir, "FULL.mp3")
    vocals = os.path.join(tmp_dir, "FULL_(Vocals)_model_bs_roformer.mp3")
    other = os.path.join(tmp_dir, "FULL_(Instrumental)_model_bs_roformer.mp3")
    for p, payload in [(full, b"FULL"), (vocals, b"VOC"), (other, b"OTH")]:
        with open(p, "wb") as f:
            f.write(payload)
    return full, vocals, other


class _FakeSeparator:
    """Drop-in for StemSeparator — doesn't touch torch/audio-separator."""

    def __init__(self, vocals_path: str, instrumental_path: str) -> None:
        self._v = vocals_path
        self._i = instrumental_path
        self.separate_calls = 0

    def load(self) -> None:
        pass

    def separate(self, input_path: str, output_dir: str, trace_id: str) -> tuple[str, str]:
        self.separate_calls += 1
        return self._v, self._i


def test_processor_downloads_from_youtube_when_full_missing(
    tmp_path: Any, worker_config: WorkerConfig
) -> None:
    from src import processor

    full, vocals, instrumental = _write_stubs(str(tmp_path))
    separator = _FakeSeparator(vocals, instrumental)

    s3 = MagicMock()
    conn = MagicMock()
    conn.cursor.return_value = MagicMock()
    enqueued: list[Any] = []

    async def fake_enqueue(cfg: Any, data: Any, trace_id: str) -> str:
        enqueued.append(data)
        return "job-99"

    with (
        patch("src.processor.create_s3_client", return_value=s3),
        patch("src.processor.create_connection", return_value=conn),
        patch("src.processor.object_exists", return_value=False),
        patch("src.processor.download_audio", return_value=full) as mock_ytdl,
        patch("src.processor.upload_audio") as mock_upload,
        patch("src.queue_producer.enqueue_pitch_analysis", side_effect=fake_enqueue),
    ):
        asyncio.run(processor.process_stem_split_job(_job(), worker_config, separator))  # type: ignore[arg-type]

    mock_ytdl.assert_called_once()
    # FULL upload + VOCALS upload + OTHER upload = 3 uploads
    assert mock_upload.call_count == 3
    uploaded_keys = [call.args[2] for call in mock_upload.call_args_list]
    assert uploaded_keys == [
        "stems/song-1/DRAFT/FULL.mp3",
        "stems/song-1/DRAFT/VOCALS.mp3",
        "stems/song-1/DRAFT/OTHER.mp3",
    ]
    assert separator.separate_calls == 1
    assert len(enqueued) == 1
    assert enqueued[0].vocal_stem_key == "stems/song-1/DRAFT/VOCALS.mp3"
    assert enqueued[0].variant_id == "sv-1"
    assert enqueued[0].pitch_output_key == "pitch/song-1/sv-1/reference.json"


def test_processor_reuses_full_when_already_in_r2(
    tmp_path: Any, worker_config: WorkerConfig
) -> None:
    from src import processor

    _, vocals, instrumental = _write_stubs(str(tmp_path))
    separator = _FakeSeparator(vocals, instrumental)

    s3 = MagicMock()
    conn = MagicMock()
    conn.cursor.return_value = MagicMock()

    async def fake_enqueue(cfg: Any, data: Any, trace_id: str) -> str:
        return "job-99"

    with (
        patch("src.processor.create_s3_client", return_value=s3),
        patch("src.processor.create_connection", return_value=conn),
        patch("src.processor.object_exists", return_value=True),
        patch("src.processor.download_object", return_value=b"CACHED-FULL-BYTES"),
        patch("src.processor.download_audio") as mock_ytdl,
        patch("src.processor.upload_audio") as mock_upload,
        patch("src.queue_producer.enqueue_pitch_analysis", side_effect=fake_enqueue),
    ):
        asyncio.run(processor.process_stem_split_job(_job(), worker_config, separator))  # type: ignore[arg-type]

    mock_ytdl.assert_not_called()
    # Only VOCALS + OTHER get uploaded — FULL was reused
    assert mock_upload.call_count == 2
    uploaded_keys = [call.args[2] for call in mock_upload.call_args_list]
    assert uploaded_keys == [
        "stems/song-1/DRAFT/VOCALS.mp3",
        "stems/song-1/DRAFT/OTHER.mp3",
    ]
