"""
Tests for the shared EAV value interpretation helpers.
"""

# [review:need-review] PHASE-01/27-streak-mode-endpoint
# summary: unit tests for is_true_value/parse_number (shared EAV value parsing)

import logging

import pytest

from app.crud.values import BOOLEAN_TRUE_VALUES, is_true_value, parse_number


class TestIsTrueValue:
    """Boolean fields are stored as text; only a known set counts as true."""

    @pytest.mark.parametrize("value", sorted(BOOLEAN_TRUE_VALUES))
    def test_known_true_tokens(self, value: str) -> None:
        assert is_true_value(value) is True

    @pytest.mark.parametrize("value", ["  TRUE  ", "Yes", "1"])
    def test_case_and_whitespace_insensitive(self, value: str) -> None:
        assert is_true_value(value) is True

    @pytest.mark.parametrize("value", [None, "", "   ", "false", "0", "no", "maybe"])
    def test_falsy_values(self, value: str | None) -> None:
        assert is_true_value(value) is False


class TestParseNumber:
    """Number fields are stored as text; unparsable text yields None."""

    def test_parses_int_and_float(self) -> None:
        assert parse_number("3") == 3.0
        assert parse_number("2.5") == 2.5
        assert parse_number(" -1.5 ") == -1.5

    @pytest.mark.parametrize("value", [None, "", "   "])
    def test_blank_is_none_without_warning(
        self, value: str | None, caplog: pytest.LogCaptureFixture
    ) -> None:
        """EntryForm submits '' for every untouched field — must stay silent."""
        with caplog.at_level(logging.WARNING, logger="app.crud.values"):
            assert parse_number(value) is None
        assert caplog.records == []

    def test_non_numeric_returns_none_and_warns(
        self, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.WARNING, logger="app.crud.values"):
            assert parse_number("abc", field_id=7, entry_id=9) is None
        assert len(caplog.records) == 1
        record = caplog.records[0]
        assert "abc" not in record.getMessage()
        # `extra=` sets these dynamically, so they are not on the LogRecord type
        assert getattr(record, "field_id") == 7
        assert getattr(record, "entry_id") == 9
