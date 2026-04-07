"""Unit tests for DB helpers — SQL shape verified against a fake cursor."""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

from src.db import complete_stem_split, mark_song_failed, mark_song_splitting


def _make_conn() -> tuple[Any, Any]:
    cursor = MagicMock()
    conn = MagicMock()
    conn.cursor.return_value = cursor
    return conn, cursor


class TestMarkSongSplitting:
    def test_runs_update_and_commits(self) -> None:
        conn, cursor = _make_conn()
        mark_song_splitting(conn, "song-1", "trace-1")
        assert cursor.execute.called
        sql = cursor.execute.call_args[0][0]
        assert "SET status = 'SPLITTING'" in sql
        assert "'QUEUED'" in sql
        conn.commit.assert_called_once()


class TestCompleteStemSplit:
    def test_upserts_each_stem_and_transitions_song(self) -> None:
        conn, cursor = _make_conn()
        stems = [
            ("FULL", "stems/song-1/FULL.mp3", 1000),
            ("VOCALS", "stems/song-1/VOCALS.mp3", 500),
            ("OTHER", "stems/song-1/OTHER.mp3", 600),
        ]
        complete_stem_split(conn, "song-1", stems, "trace-1")

        # 3 inserts + 1 song update = 4 execute calls
        assert cursor.execute.call_count == 4
        insert_sqls = [c[0][0] for c in cursor.execute.call_args_list[:3]]
        for sql in insert_sqls:
            assert 'INSERT INTO "Stem"' in sql
            assert "ON CONFLICT" in sql

        final_sql = cursor.execute.call_args_list[3][0][0]
        assert "SET status = 'ANALYZING'" in final_sql
        conn.commit.assert_called_once()

    def test_rolls_back_on_error(self) -> None:
        conn, cursor = _make_conn()
        cursor.execute.side_effect = RuntimeError("boom")
        try:
            complete_stem_split(conn, "song-1", [("FULL", "k", 1)], "trace-1")
        except RuntimeError:
            pass
        conn.rollback.assert_called_once()


class TestMarkSongFailed:
    def test_sets_status_and_error(self) -> None:
        conn, cursor = _make_conn()
        mark_song_failed(conn, "song-1", "kaboom", "trace-1")
        sql, params = cursor.execute.call_args[0]
        assert "SET status = 'FAILED'" in sql
        assert params == ("kaboom", "song-1")
        conn.commit.assert_called_once()
