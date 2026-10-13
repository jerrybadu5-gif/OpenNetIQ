"""Exit criteria: 1 s sampling sustained >= 2 h with <= 1 % missing samples;
battery drain <= 15 %/h during passive logging."""

from __future__ import annotations

from dataclasses import dataclass, field

from .io import Row, median, parse_float, parse_time

MIN_DURATION_H = 2.0
MAX_MISSING = 0.01
MAX_DRAIN_PER_H = 15.0


@dataclass(frozen=True)
class Gap:
    start: str
    end: str
    seconds: float


@dataclass(frozen=True)
class SamplingReport:
    samples: int
    interval_s: float
    duration_h: float
    expected: int
    missing_pct: float
    fix_pct: float
    median_h_accuracy_m: float | None
    gaps: list[Gap] = field(default_factory=list)
    battery_drain_pct_per_h: float | None = None

    @property
    def sampling_passed(self) -> bool:
        return self.duration_h >= MIN_DURATION_H and self.missing_pct <= MAX_MISSING * 100

    @property
    def battery_passed(self) -> bool | None:
        if self.battery_drain_pct_per_h is None:
            return None
        return self.battery_drain_pct_per_h <= MAX_DRAIN_PER_H


def analyse(
    rows: list[Row],
    interval_s: float = 1.0,
    battery_start: float | None = None,
    battery_end: float | None = None,
) -> SamplingReport:
    """Missing = 1 - samples / expected, expected = duration / interval + 1.
    A gap is a step longer than 1.5 x interval (pauses count as gaps)."""
    times = sorted(t for r in rows if (t := parse_time(r.get("timestamp"))) is not None)
    if len(times) < 2:
        return SamplingReport(len(times), interval_s, 0.0, len(times), 0.0, 0.0, None)
    duration = (times[-1] - times[0]).total_seconds()
    expected = int(duration / interval_s) + 1
    missing = max(0.0, 1 - len(times) / expected) * 100
    gaps = [
        Gap(a.isoformat(), b.isoformat(), (b - a).total_seconds())
        for a, b in zip(times, times[1:], strict=False)
        if (b - a).total_seconds() > 1.5 * interval_s
    ]
    fixes = [r for r in rows if parse_float(r.get("lat")) is not None]
    accuracy = [a for r in fixes if (a := parse_float(r.get("h_accuracy_m"))) is not None]
    hours = duration / 3600
    drain = None
    if battery_start is not None and battery_end is not None and hours > 0:
        drain = (battery_start - battery_end) / hours
    return SamplingReport(
        samples=len(times),
        interval_s=interval_s,
        duration_h=hours,
        expected=expected,
        missing_pct=missing,
        fix_pct=len(fixes) / len(rows) * 100,
        median_h_accuracy_m=median(accuracy),
        gaps=gaps,
        battery_drain_pct_per_h=drain,
    )
