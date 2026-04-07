"""PostgreSQL operations for stem persistence and Song state transitions."""

from __future__ import annotations

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


def mark_song_splitting(conn: Any, song_id: str, trace_id: str) -> None:
    """Transition Song from QUEUED -> SPLITTING. Idempotent (no-op if not QUEUED)."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "Song"
            SET status = 'SPLITTING', "updatedAt" = NOW()
            WHERE id = %s AND status IN ('QUEUED', 'FAILED')
            """,
            (song_id,),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.INFO,
            "Song marked SPLITTING",
            traceId=trace_id,
            songId=song_id,
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def complete_stem_split(
    conn: Any,
    song_id: str,
    stems: list[tuple[str, str, int]],
    trace_id: str,
) -> None:
    """Upsert Stem rows and transition Song -> ANALYZING in a single transaction.

    `stems` is a list of `(stem_type, storage_key, file_size)` tuples.
    Upsert is keyed on the unique `(songId, type)` index — re-runs replace
    storageKey/fileSize so reprocessing is idempotent.
    """
    start = time.monotonic()
    cursor = conn.cursor()
    try:
        for stem_type, storage_key, file_size in stems:
            cursor.execute(
                """
                INSERT INTO "Stem"
                    (id, "songId", type, "storageKey", format, "fileSize", "createdAt")
                VALUES (gen_random_uuid()::text, %s, %s::"StemType", %s, 'mp3', %s, NOW())
                ON CONFLICT ("songId", type) DO UPDATE
                SET "storageKey" = EXCLUDED."storageKey",
                    "fileSize"   = EXCLUDED."fileSize"
                """,
                (song_id, stem_type, storage_key, file_size),
            )

        cursor.execute(
            """
            UPDATE "Song"
            SET status = 'ANALYZING', "updatedAt" = NOW(), "errorMessage" = NULL
            WHERE id = %s AND status IN ('SPLITTING', 'QUEUED', 'FAILED', 'READY')
            """,
            (song_id,),
        )

        conn.commit()
        log_with_context(
            logger,
            logging.INFO,
            "Stems persisted, Song -> ANALYZING",
            traceId=trace_id,
            songId=song_id,
            stemCount=len(stems),
            durationMs=int((time.monotonic() - start) * 1000),
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def mark_variant_splitting(conn: Any, variant_id: str, trace_id: str) -> None:
    """Transition SongVariant to SPLITTING."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "SongVariant"
            SET status = 'SPLITTING', "updatedAt" = NOW()
            WHERE id = %s
            """,
            (variant_id,),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.INFO,
            "Variant marked SPLITTING",
            traceId=trace_id,
            variantId=variant_id,
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def mark_variant_analyzing(conn: Any, variant_id: str, trace_id: str) -> None:
    """Transition SongVariant to ANALYZING."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "SongVariant"
            SET status = 'ANALYZING', "updatedAt" = NOW(), "errorMessage" = NULL
            WHERE id = %s
            """,
            (variant_id,),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.INFO,
            "Variant marked ANALYZING",
            traceId=trace_id,
            variantId=variant_id,
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()


def mark_variant_failed(
    conn: Any, variant_id: str, error_message: str, trace_id: str
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


def mark_song_failed(conn: Any, song_id: str, error_message: str, trace_id: str) -> None:
    """Update Song status to FAILED with an error message."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            UPDATE "Song"
            SET status = 'FAILED', "errorMessage" = %s, "updatedAt" = NOW()
            WHERE id = %s
            """,
            (error_message, song_id),
        )
        conn.commit()
        log_with_context(
            logger,
            logging.WARNING,
            "Song marked FAILED",
            traceId=trace_id,
            songId=song_id,
            errorMessage=error_message,
        )
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()
