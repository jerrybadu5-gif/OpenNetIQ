"""CSV loading and timestamp/number parsing shared by all checks."""

from __future__ import annotations

import csv
import math
from datetime import UTC, datetime, timedelta
from pathlib import Path

Row = dict[str, str]


def read_csv(path: str | Path) -> list[Row]:
    """Reads a CSV with a header row (UTF-8, optional BOM)."""
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def parse_float(value: str | None) -> float | None:
    """Empty, non-numeric and NaN values are None (never 0)."""
    if value is None:
        return None
    text = value.strip()
    if not text:
        return None
    try:
        number = float(text)
    except ValueError:
        return None
    return None if number != number else number


def parse_time(
    value: str | None, fmt: str | None = None, utc_offset_h: float = 0
) -> datetime | None:
    """Parses ISO 8601 (with `Z`/offset) or `fmt` (naive, shifted by `utc_offset_h`) to UTC."""
    if not value or not value.strip():
        return None
    text = value.strip()
    try:
        if fmt:
            naive = datetime.strptime(text, fmt)
            return (naive - timedelta(hours=utc_offset_h)).replace(tzinfo=UTC)
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = (parsed - timedelta(hours=utc_offset_h)).replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def percentile(values: list[float], p: float) -> float | None:
    """Nearest-rank percentile (same definition as the app's KPIs)."""
    if not values:
        return None
    ordered = sorted(values)
    rank = max(1, math.ceil(p * len(ordered)))
    return ordered[min(rank, len(ordered)) - 1]


def median(values: list[float]) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    return ordered[mid] if len(ordered) % 2 else (ordered[mid - 1] + ordered[mid]) / 2
