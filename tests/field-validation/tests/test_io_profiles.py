from datetime import UTC, datetime

import pytest

from onq_validation.io import median, parse_float, parse_time, percentile
from onq_validation.profiles import PROFILES, parse_overrides


def test_parse_float_never_zero_for_missing():
    assert parse_float("") is None
    assert parse_float(None) is None
    assert parse_float(" x ") is None
    assert parse_float("nan") is None
    assert parse_float("-88.5") == -88.5


def test_parse_time_variants():
    want = datetime(2026, 10, 13, 1, 0, 0, tzinfo=UTC)
    assert parse_time("2026-10-13T01:00:00.000Z") == want
    assert parse_time("2026-10-13T11:00:00+10:00") == want
    assert parse_time("2026-10-13 11:00:00", utc_offset_h=10) == want
    assert parse_time("2026.10.13_11.00.00", "%Y.%m.%d_%H.%M.%S", 10) == want
    assert parse_time("garbage") is None
    assert parse_time("2026.10.13", "%Y.%m.%d_%H.%M.%S") is None
    assert parse_time("  ") is None


def test_percentile_and_median():
    assert percentile([], 0.9) is None
    assert percentile([5, 1, 3, 2, 4], 0.9) == 5
    assert percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 0.9) == 9
    assert median([]) is None
    assert median([3, 1, 2]) == 2
    assert median([4, 1, 2, 3]) == 2.5


def test_profile_overrides():
    p = PROFILES["gnettrack"].with_overrides(parse_overrides(["pci=PCI", "time=Time"]))
    assert p.columns["pci"] == "PCI"
    assert p.time == "Time"
    assert p.time_format == "%Y.%m.%d_%H.%M.%S"
    with pytest.raises(ValueError):
        parse_overrides(["rsrp"])
    with pytest.raises(ValueError):
        parse_overrides(["=x"])
    assert parse_overrides(None) == {}
