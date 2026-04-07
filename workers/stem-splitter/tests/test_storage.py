"""Tests for R2 storage helpers."""

from __future__ import annotations

from unittest.mock import MagicMock

from botocore.exceptions import ClientError

from src.storage import object_exists


def _make_404() -> ClientError:
    return ClientError(
        error_response={"Error": {"Code": "404", "Message": "Not Found"}},
        operation_name="HeadObject",
    )


class TestObjectExists:
    def test_returns_true_when_head_succeeds(self) -> None:
        client = MagicMock()
        client.head_object.return_value = {}
        assert object_exists(client, "bucket", "key") is True

    def test_returns_false_on_404(self) -> None:
        client = MagicMock()
        client.head_object.side_effect = _make_404()
        assert object_exists(client, "bucket", "key") is False

    def test_reraises_other_client_errors(self) -> None:
        client = MagicMock()
        client.head_object.side_effect = ClientError(
            error_response={"Error": {"Code": "500", "Message": "boom"}},
            operation_name="HeadObject",
        )
        try:
            object_exists(client, "bucket", "key")
            raise AssertionError("should have raised")
        except ClientError:
            pass
