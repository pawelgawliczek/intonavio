"""pYIN pitch extraction pipeline."""

import logging
import math
from io import BytesIO

import librosa
import numpy as np
from numpy.typing import NDArray
from scipy.signal import butter, sosfiltfilt

from src.config import WorkerConfig
from src.logger import get_logger, log_with_context
from src.models import AnalysisStats, PitchFrame

logger = get_logger(__name__)


def hz_to_midi(hz: float) -> float:
    """Convert frequency in Hz to MIDI note number."""
    return 69.0 + 12.0 * math.log2(hz / 440.0)


def build_frames(
    f0: NDArray[np.float64],
    voiced_flag: NDArray[np.bool_],
    rms_values: NDArray[np.float64],
    sample_rate: int,
    hop_length: int,
) -> list[PitchFrame]:
    """Convert numpy arrays from pYIN into a list of PitchFrame objects."""
    frames: list[PitchFrame] = []
    hop_duration = hop_length / sample_rate

    for i in range(len(f0)):
        t = round(i * hop_duration, 4)
        is_voiced = bool(voiced_flag[i]) and not np.isnan(f0[i])
        rms_val = round(float(rms_values[i]), 6) if i < len(rms_values) else None

        if is_voiced:
            hz_val = float(f0[i])
            midi_val = round(hz_to_midi(hz_val), 1)
            frames.append(PitchFrame(t=t, hz=hz_val, midi=midi_val, voiced=True, rms=rms_val))
        else:
            frames.append(PitchFrame(t=t, hz=None, midi=None, voiced=False, rms=rms_val))

    return frames


def fix_octave_errors(
    frames: list[PitchFrame],
    window_size: int = 51,
    semitone_threshold: float = 10.0,
) -> list[PitchFrame]:
    """Correct octave errors by comparing each frame to a local median pitch.

    pYIN sometimes locks onto the 2nd harmonic (octave up) or sub-harmonic
    (octave down) for short spans.  A sliding-window median of surrounding
    voiced MIDI values provides a robust local reference.  Any frame that
    deviates by roughly one octave (±semitone_threshold) is shifted back.
    """
    midi_values = [f.midi if f.voiced and f.midi is not None else np.nan for f in frames]
    midi_arr = np.array(midi_values, dtype=np.float64)

    n = len(midi_arr)
    half_w = window_size // 2
    corrected = list(frames)

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
        if diff > semitone_threshold and f.hz is not None:
            new_hz = round(f.hz / 2, 1)
            new_midi = round(hz_to_midi(new_hz), 1)
            corrected[i] = PitchFrame(t=f.t, hz=new_hz, midi=new_midi, voiced=True, rms=f.rms)
        elif diff < -semitone_threshold and f.hz is not None:
            new_hz = round(f.hz * 2, 1)
            new_midi = round(hz_to_midi(new_hz), 1)
            corrected[i] = PitchFrame(t=f.t, hz=new_hz, midi=new_midi, voiced=True, rms=f.rms)

    return corrected


def compute_stats(frames: list[PitchFrame]) -> AnalysisStats:
    """Compute validation statistics from extracted frames."""
    frame_count = len(frames)
    voiced = [f for f in frames if f.voiced and f.hz is not None]
    voiced_count = len(voiced)

    if frame_count == 0:
        return AnalysisStats(
            frame_count=0,
            voiced_frame_count=0,
            voiced_frame_percent=0.0,
            frequency_min=None,
            frequency_max=None,
            is_valid=False,
        )

    voiced_percent = (voiced_count / frame_count) * 100.0
    voiced_hz = [f.hz for f in voiced if f.hz is not None]
    freq_min = min(voiced_hz) if voiced_hz else None
    freq_max = max(voiced_hz) if voiced_hz else None

    return AnalysisStats(
        frame_count=frame_count,
        voiced_frame_count=voiced_count,
        voiced_frame_percent=round(voiced_percent, 1),
        frequency_min=freq_min,
        frequency_max=freq_max,
        is_valid=True,
    )


def validate_analysis(stats: AnalysisStats, max_unvoiced_ratio: float) -> bool:
    """Reject if 0 frames or more than max_unvoiced_ratio are unvoiced."""
    if stats.frame_count == 0:
        return False
    unvoiced_ratio = 1.0 - (stats.voiced_frame_count / stats.frame_count)
    return unvoiced_ratio <= max_unvoiced_ratio


def extract_pitch(
    audio_bytes: bytes,
    config: WorkerConfig,
    trace_id: str,
) -> tuple[list[PitchFrame], AnalysisStats]:
    """Run pYIN on audio bytes and return frames + stats."""
    log_with_context(
        logger,
        logging.INFO,
        "Starting pYIN extraction",
        traceId=trace_id,
        fmin=config.pyin_fmin,
        fmax=config.pyin_fmax,
        hopLength=config.pyin_hop_length,
        sampleRate=config.pyin_sample_rate,
    )

    y, _ = librosa.load(
        BytesIO(audio_bytes),
        sr=config.pyin_sample_rate,
        mono=True,
    )

    # Bandpass 65–1100 Hz to the human vocal range before pitch extraction.
    # Anything above ~1100 Hz in a vocal stem is instrument bleed or harmonics
    # (highest soprano C6 ≈ 1047 Hz), so filtering it out mathematically
    # prevents pYIN from tracking those artifacts.
    nyquist = config.pyin_sample_rate / 2
    sos = butter(
        4,
        [config.pyin_fmin / nyquist, config.pyin_fmax / nyquist],
        btype="bandpass",
        output="sos",
    )
    y = sosfiltfilt(sos, y).astype(np.float32)

    f0, voiced_flag, _ = librosa.pyin(
        y,
        fmin=config.pyin_fmin,
        fmax=config.pyin_fmax,
        sr=config.pyin_sample_rate,
        hop_length=config.pyin_hop_length,
    )

    rms = librosa.feature.rms(y=y, hop_length=config.pyin_hop_length)[0]

    frames = build_frames(
        f0,
        voiced_flag,
        rms,
        config.pyin_sample_rate,
        config.pyin_hop_length,
    )
    frames = fix_octave_errors(frames)
    stats = compute_stats(frames)

    if stats.voiced_frame_percent < 10.0:
        log_with_context(
            logger,
            logging.WARNING,
            "Low voiced frame percentage — possible bad audio",
            traceId=trace_id,
            voicedFramePercent=stats.voiced_frame_percent,
        )

    log_with_context(
        logger,
        logging.INFO,
        "pYIN extraction complete",
        traceId=trace_id,
        frameCount=stats.frame_count,
        voicedFramePercent=stats.voiced_frame_percent,
        frequencyMin=stats.frequency_min,
        frequencyMax=stats.frequency_max,
    )

    return frames, stats
