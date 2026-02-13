"""Tests for PostgreSQL adapter (mocked psycopg2)."""

import contextlib
from unittest.mock import MagicMock

from src.db import complete_pitch_analysis, mark_song_failed


def test_complete_pitch_analysis_executes_upsert_and_update(
    mock_db_conn: MagicMock,
) -> None:
    """Both INSERT and UPDATE are executed in a transaction."""
    result = complete_pitch_analysis(
        mock_db_conn,
        "song-1",
        "pitch/song-1/reference.json",
        172,
        0.01161,
        "trace-1",
    )

    cursor = mock_db_conn.cursor.return_value
    assert cursor.execute.call_count == 2
    mock_db_conn.commit.assert_called_once()
    assert result == "test-pitch-data-id"


def test_complete_pitch_analysis_idempotent_upsert(
    mock_db_conn: MagicMock,
) -> None:
    """SQL uses ON CONFLICT for idempotent upsert."""
    complete_pitch_analysis(
        mock_db_conn,
        "song-1",
        "pitch/song-1/reference.json",
        172,
        0.01161,
        "trace-1",
    )

    cursor = mock_db_conn.cursor.return_value
    insert_sql = cursor.execute.call_args_list[0][0][0]
    assert "ON CONFLICT" in insert_sql
    assert "DO UPDATE" in insert_sql


def test_complete_pitch_analysis_guards_status(
    mock_db_conn: MagicMock,
) -> None:
    """UPDATE only transitions ANALYZING -> READY."""
    complete_pitch_analysis(
        mock_db_conn,
        "song-1",
        "pitch/song-1/reference.json",
        172,
        0.01161,
        "trace-1",
    )

    cursor = mock_db_conn.cursor.return_value
    update_sql = cursor.execute.call_args_list[1][0][0]
    assert "status = 'ANALYZING'" in update_sql
    assert "status = 'READY'" in update_sql


def test_complete_pitch_analysis_rollback_on_error(
    mock_db_conn: MagicMock,
) -> None:
    """Transaction is rolled back on error."""
    cursor = mock_db_conn.cursor.return_value
    cursor.execute.side_effect = Exception("DB error")

    with contextlib.suppress(Exception):
        complete_pitch_analysis(
            mock_db_conn,
            "song-1",
            "key",
            100,
            0.01,
            "trace-1",
        )

    mock_db_conn.rollback.assert_called_once()


def test_mark_song_failed(mock_db_conn: MagicMock) -> None:
    """mark_song_failed updates status and error message."""
    mark_song_failed(mock_db_conn, "song-1", "Bad audio", "trace-1")

    cursor = mock_db_conn.cursor.return_value
    cursor.execute.assert_called_once()
    sql = cursor.execute.call_args[0][0]
    assert "FAILED" in sql
    assert "errorMessage" in sql
    mock_db_conn.commit.assert_called_once()
