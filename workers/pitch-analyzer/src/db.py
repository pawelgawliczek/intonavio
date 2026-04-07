"""PostgreSQL operations for pitch analysis results."""

import logging
import time
from typing import Any

import psycopg2

from src.config import WorkerConfig
from src.logger import get_logger, log_with_context

logger = get_logger(__name__)


def create_connection(config: WorkerConfig) -> Any:
    """Create a psycopg2 connection from DATABASE_URL."""
    return psycopg2.connect(config.database_url)


def complete_pitch_analysis(
    conn: Any,
    song_id: str,
    storage_key: str,
    frame_count: int,
    hop_duration: float,
    trace_id: str,
) -> str:
    """Upsert PitchData and update Song status to READY in a single transaction.

    Returns the PitchData ID.
    """
    start = time.monotonic()
    cursor = conn.cursor()
    try:
        # Idempotent upsert — ON CONFLICT updates existing record
        cursor.execute(
            """
            INSERT INTO "PitchData"
                (id, "songId", "storageKey", "frameCount", "hopDuration", "createdAt")
            VALUES (gen_random_uuid()::text, %s, %s, %s, %s, NOW())
            ON CONFLICT ("songId") DO UPDATE
            SET "storageKey" = EXCLUDED."storageKey",
                "frameCount" = EXCLUDED."frameCount",
                "hopDuration" = EXCLUDED."hopDuration"
            RETURNING id
            """,
            (song_id, storage_key, frame_count, hop_duration),
        )
        row = cursor.fetchone()
        pitch_data_id: str = row[0] if row else ""

        # Only transition ANALYZING -> READY (guard clause for idempotency)
        cursor.execute(
            """
            UPDATE "Song"
            SET status = 'READY', "updatedAt" = NOW()
            WHERE id = %s AND status = 'ANALYZING'
            """,
            (song_id,),
        )

        conn.commit()

        duration_ms = int((time.monotonic() - start) * 1000)
        log_with_context(
            logger,
            logging.INFO,
            "Pitch analysis persisted",
            traceId=trace_id,
            songId=song_id,
            pitchDataId=pitch_data_id,
            durationMs=duration_ms,
        )
        return pitch_data_id
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def complete_variant_pitch_analysis(
    conn: Any,
    variant_id: str,
    song_id: str,
    storage_key: str,
    frame_count: int,
    hop_duration: float,
    trace_id: str,
) -> None:
    """Persist pitch data on the SongVariant row and flip its status to READY.

    Also transitions the parent Song to READY if it is still ANALYZING.
    """
    start = time.monotonic()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "SongVariant"
            SET "pitchKey" = %s,
                "frameCount" = %s,
                "hopDuration" = %s,
                status = 'READY',
                "errorMessage" = NULL,
                "updatedAt" = NOW()
            WHERE id = %s
            """,
            (storage_key, frame_count, hop_duration, variant_id),
        )
        cursor.execute(
            """
            UPDATE "Song"
            SET status = 'READY', "updatedAt" = NOW()
            WHERE id = %s AND status = 'ANALYZING'
            """,
            (song_id,),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.INFO,
            "Variant pitch analysis persisted",
            traceId=trace_id,
            songId=song_id,
            variantId=variant_id,
            durationMs=int((time.monotonic() - start) * 1000),
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def mark_variant_failed(
    conn: Any,
    variant_id: str,
    error_message: str,
    trace_id: str,
) -> None:
    """Mark a SongVariant as FAILED."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "SongVariant"
            SET status = 'FAILED', "errorMessage" = %s, "updatedAt" = NOW()
            WHERE id = %s
            """,
            (error_message, variant_id),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.WARNING,
            "Variant marked FAILED",
            traceId=trace_id,
            variantId=variant_id,
            errorMessage=error_message,
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def mark_song_failed(
    conn: Any,
    song_id: str,
    error_message: str,
    trace_id: str,
) -> None:
    """Update Song status to FAILED with an error message."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "Song"
            SET status = 'FAILED', "errorMessage" = %s, "updatedAt" = NOW()
            WHERE id = %s AND status = 'ANALYZING'
            """,
            (error_message, song_id),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.WARNING,
            "Song marked as FAILED",
            traceId=trace_id,
            songId=song_id,
            errorMessage=error_message,
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()
