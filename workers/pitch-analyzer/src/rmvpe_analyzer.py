"""Thin wrapper around the vendored RMVPE inference module.

Exposes the small surface the worker actually needs:
    - load_rmvpe(model_path)
    - extract_rmvpe_candidates(rmvpe, audio_bytes) -> list[PitchCandidate]
    - RMVPE_HOP_SECONDS — RMVPE's native frame hop (10 ms @ 16 kHz, hard-coded
      in the model architecture).
"""

from __future__ import annotations

import io

import numpy as np

from src.reconcile import PitchCandidate

# RMVPE is hard-coded to a 160-sample hop at 16 kHz inside MelSpectrogram —
# that's exactly 10 ms per frame. Treat as a constant.
RMVPE_HOP_SECONDS = 0.01


def load_rmvpe(model_path: str):  # noqa: ANN201 — torch type only at runtime
    """Construct and return a CPU, full-precision RMVPE inference model."""
    from src.rmvpe import RMVPE

    return RMVPE(model_path, is_half=False, device="cpu")


def extract_rmvpe_candidates(
    rmvpe,  # noqa: ANN001 — opaque torch wrapper
    audio_bytes: bytes,
    thred: float = 0.03,
) -> list[PitchCandidate]:
    """Decode the audio bytes to 16 kHz mono, run RMVPE, return per-frame candidates.

    RMVPE does not expose a per-frame confidence directly — use a proxy: 1.0 when
    hz > 0 (voiced), 0.0 otherwise. RMVPE's internal `thred` already filters
    low-confidence frames. This keeps reconcile's threshold behavior meaningful
    when combined with pYIN's real voiced_prob.
    """
    import librosa

    y, _ = librosa.load(io.BytesIO(audio_bytes), sr=16000, mono=True)
    f0 = rmvpe.infer_from_audio(y.astype(np.float32), thred=thred)
    candidates: list[PitchCandidate] = []
    for hz in f0:
        hz_f = float(hz)
        if hz_f > 0.0:
            candidates.append(PitchCandidate(hz=hz_f, confidence=1.0))
        else:
            candidates.append(PitchCandidate(hz=None, confidence=0.0))
    return candidates
