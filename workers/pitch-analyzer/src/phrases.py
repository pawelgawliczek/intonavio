"""Phrase detection: split pitch frames into singable phrases based on silence gaps."""

from src.models import Phrase, PitchFrame


def detect_phrases(
    frames: list[PitchFrame],
    hop_duration: float,
    min_gap_seconds: float = 0.3,
    min_phrase_seconds: float = 0.5,
    rms_threshold: float = 0.02,
) -> list[Phrase]:
    """Detect phrases by finding contiguous runs of voiced+audible frames.

    A phrase boundary occurs when an unvoiced/inaudible gap exceeds
    ``min_gap_seconds``. Short phrases (< ``min_phrase_seconds`` of voiced
    content) are merged with their nearest neighbor.
    """
    raw = _find_raw_phrases(frames, hop_duration, min_gap_seconds, rms_threshold)
    merged = _merge_short_phrases(raw, min_phrase_seconds, hop_duration)
    return _reindex(merged, frames, hop_duration)


def _is_active(frame: PitchFrame, rms_threshold: float) -> bool:
    if not frame.voiced:
        return False
    if frame.rms is not None and frame.rms < rms_threshold:
        return False
    return True


def _find_raw_phrases(
    frames: list[PitchFrame],
    hop_duration: float,
    min_gap_seconds: float,
    rms_threshold: float,
) -> list[tuple[int, int]]:
    """Return (start_frame, end_frame) inclusive pairs for raw phrases."""
    min_gap_frames = int(min_gap_seconds / hop_duration) if hop_duration > 0 else 0
    phrases: list[tuple[int, int]] = []
    phrase_start: int | None = None
    gap_count = 0

    for i, frame in enumerate(frames):
        if _is_active(frame, rms_threshold):
            if phrase_start is None:
                phrase_start = i
            gap_count = 0
        else:
            gap_count += 1
            if phrase_start is not None and gap_count > min_gap_frames:
                phrases.append((phrase_start, i - gap_count))
                phrase_start = None
                gap_count = 0

    if phrase_start is not None:
        last_active = phrase_start
        for i in range(len(frames) - 1, phrase_start - 1, -1):
            if _is_active(frames[i], rms_threshold):
                last_active = i
                break
        phrases.append((phrase_start, last_active))

    return phrases


def _merge_short_phrases(
    phrases: list[tuple[int, int]],
    min_phrase_seconds: float,
    hop_duration: float,
) -> list[tuple[int, int]]:
    """Merge phrases shorter than min_phrase_seconds with nearest neighbor."""
    if len(phrases) <= 1:
        return phrases

    min_frames = int(min_phrase_seconds / hop_duration) if hop_duration > 0 else 0
    result = list(phrases)
    changed = True

    while changed:
        changed = False
        i = 0
        while i < len(result):
            start, end = result[i]
            voiced_count = end - start + 1
            if voiced_count >= min_frames:
                i += 1
                continue

            # Find nearest neighbor to merge with
            if i == 0 and len(result) > 1:
                merge_idx = 1
            elif i == len(result) - 1 and len(result) > 1:
                merge_idx = i - 1
            elif len(result) > 1:
                gap_before = start - result[i - 1][1]
                gap_after = result[i + 1][0] - end
                merge_idx = i - 1 if gap_before <= gap_after else i + 1
            else:
                i += 1
                continue

            lo = min(i, merge_idx)
            hi = max(i, merge_idx)
            merged = (result[lo][0], result[hi][1])
            result[lo] = merged
            result.pop(hi)
            changed = True
            break

    return result


def _reindex(
    raw: list[tuple[int, int]],
    frames: list[PitchFrame],
    hop_duration: float,
) -> list[Phrase]:
    """Convert raw (start, end) pairs into indexed Phrase models."""
    result: list[Phrase] = []
    for idx, (start, end) in enumerate(raw):
        voiced = sum(1 for i in range(start, end + 1) if frames[i].voiced)
        result.append(
            Phrase(
                index=idx,
                start_frame=start,
                end_frame=end,
                start_time=round(start * hop_duration, 6),
                end_time=round(end * hop_duration, 6),
                voiced_frame_count=voiced,
            )
        )
    return result
