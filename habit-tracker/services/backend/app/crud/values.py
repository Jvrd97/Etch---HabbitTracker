# [review:need-review] PHASE-01/27-streak-mode-endpoint
# summary: shared interpretation of EAV text values (boolean truthiness, number parsing)
import logging

logger = logging.getLogger(__name__)

# String values treated as "true" for boolean fields (EAV stores text)
BOOLEAN_TRUE_VALUES = frozenset({"true", "1", "yes"})


def is_true_value(value: str | None) -> bool:
    """Whether a stored boolean field value means true."""
    if value is None:
        return False
    return value.strip().lower() in BOOLEAN_TRUE_VALUES


def parse_number(
    value: str | None, *, field_id: int | None = None, entry_id: int | None = None
) -> float | None:
    """
    Parse a stored number field value, or None when it carries no number.

    A missing or blank value is silently None: the entry form submits an empty
    string for every field the user did not touch, so blanks are expected and
    must not produce log noise. Text that is present but unparsable is a real
    data problem and is logged as a warning — the value itself is never logged
    (PII-safe), only the ids needed to locate the row.
    """
    if value is None or not value.strip():
        return None
    try:
        return float(value)
    except ValueError:
        logger.warning(
            "non-numeric value in number field",
            extra={"field_id": field_id, "entry_id": entry_id},
        )
        return None
