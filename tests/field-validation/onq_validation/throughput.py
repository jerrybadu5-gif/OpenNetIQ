"""Exit criterion: DL/UL within ±10 % of a reference test (same server,
same location), n >= 30 pairs."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from .io import Row, median, parse_float, parse_time

LIMIT = 0.10
MIN_PAIRS = 30


@dataclass(frozen=True)
class RefTest:
    time: datetime
    dl_mbps: float | None
    ul_mbps: float | None


@dataclass(frozen=True)
class DirectionResult:
    direction: str
    pairs: int
    median_abs_rel_diff: float | None
    mean_rel_bias: float | None  # (OpenNetIQ - reference) / reference

    @property
    def passed(self) -> bool:
        return (
            self.pairs >= MIN_PAIRS
            and self.median_abs_rel_diff is not None
            and self.median_abs_rel_diff <= LIMIT
        )


@dataclass(frozen=True)
class ThroughputReport:
    onq_tests: int
    ref_tests: int
    matched: int
    directions: list[DirectionResult]

    @property
    def passed(self) -> bool:
        return all(d.passed for d in self.directions)


def load_reference(
    rows: list[Row],
    time_col: str = "timestamp",
    dl_col: str = "dl_mbps",
    ul_col: str = "ul_mbps",
    time_format: str | None = None,
    utc_offset_h: float = 0,
) -> list[RefTest]:
    tests = []
    for r in rows:
        at = parse_time(r.get(time_col), time_format, utc_offset_h)
        if at is not None:
            tests.append(RefTest(at, parse_float(r.get(dl_col)), parse_float(r.get(ul_col))))
    return sorted(tests, key=lambda t: t.time)


def compare(
    onq_rows: list[Row], reference: list[RefTest], window_s: float = 300
) -> ThroughputReport:
    """Pairs each OpenNetIQ speed test (`ok`/`partial`) with the closest unused
    reference test within `window_s` (tests are run back to back)."""
    window = timedelta(seconds=window_s)
    ours = [
        r
        for r in onq_rows
        if r.get("test_type") == "speed" and r.get("status") in ("ok", "partial")
    ]
    used: set[int] = set()
    rel: dict[str, list[float]] = {"download": [], "upload": []}
    matched = 0
    for row in ours:
        at = parse_time(row.get("timestamp"))
        if at is None:
            continue
        best = None
        for i, ref in enumerate(reference):
            gap = abs(ref.time - at)
            if i not in used and gap <= window and (best is None or gap < best[1]):
                best = (i, gap)
        if best is None:
            continue
        used.add(best[0])
        matched += 1
        ref = reference[best[0]]
        for direction, ours_col, theirs in (
            ("download", "dl_mean_mbps", ref.dl_mbps),
            ("upload", "ul_mean_mbps", ref.ul_mbps),
        ):
            value = parse_float(row.get(ours_col))
            if value is not None and theirs:
                rel[direction].append((value - theirs) / theirs)
    return ThroughputReport(
        onq_tests=len(ours),
        ref_tests=len(reference),
        matched=matched,
        directions=[
            DirectionResult(
                direction=d,
                pairs=len(v),
                median_abs_rel_diff=median([abs(x) for x in v]),
                mean_rel_bias=sum(v) / len(v) if v else None,
            )
            for d, v in rel.items()
        ],
    )
