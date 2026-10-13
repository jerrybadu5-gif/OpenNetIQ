"""Exit criterion: RSRP/RSRQ within ±2 dB median absolute difference."""

from __future__ import annotations

import bisect
from dataclasses import dataclass
from datetime import datetime, timedelta

from .io import Row, median, parse_float, parse_time, percentile
from .profiles import RadioProfile

METRICS = {
    # metric: (OpenNetIQ column, limit dB)
    "rsrp": ("serving_rsrp_dbm", 2.0),
    "rsrq": ("serving_rsrq_db", 2.0),
    "sinr": ("serving_sinr_db", None),  # reported, no exit criterion
}


@dataclass(frozen=True)
class RefPoint:
    time: datetime
    values: dict[str, float | None]
    pci: str | None


@dataclass(frozen=True)
class MetricResult:
    metric: str
    pairs: int
    median_abs_diff: float | None
    mean_bias: float | None  # OpenNetIQ minus reference
    p90_abs_diff: float | None
    limit: float | None

    @property
    def passed(self) -> bool | None:
        if self.limit is None or self.median_abs_diff is None:
            return None
        return self.median_abs_diff <= self.limit


@dataclass(frozen=True)
class RadioReport:
    onq_samples: int
    lte_samples: int
    ref_points: int
    matched: int
    pci_checked: int
    pci_agreement: float | None
    metrics: list[MetricResult]

    @property
    def passed(self) -> bool:
        graded = [m.passed for m in self.metrics if m.passed is not None]
        return bool(graded) and all(graded)


def load_reference(
    rows: list[Row], profile: RadioProfile, utc_offset_h: float = 0
) -> list[RefPoint]:
    points: list[RefPoint] = []
    for r in rows:
        at = parse_time(r.get(profile.time), profile.time_format, utc_offset_h)
        if at is None:
            continue
        values = {}
        for metric in METRICS:
            col = profile.columns.get(metric)
            values[metric] = parse_float(r.get(col)) if col else None
        pci_col = profile.columns.get("pci")
        pci = (r.get(pci_col) or "").strip() or None if pci_col else None
        points.append(RefPoint(at, values, pci))
    points.sort(key=lambda p: p.time)
    return points


def _nearest(
    points: list[RefPoint], times: list[datetime], at: datetime, tol: timedelta
) -> RefPoint | None:
    i = bisect.bisect_left(times, at)
    best = None
    for j in (i - 1, i):
        if 0 <= j < len(points):
            gap = abs(points[j].time - at)
            if gap <= tol and (best is None or gap < abs(best.time - at)):
                best = points[j]
    return best


def compare(
    onq_rows: list[Row],
    reference: list[RefPoint],
    tolerance_s: float = 0.5,
    offset_s: float = 0,
) -> RadioReport:
    """Pairs each OpenNetIQ LTE sample with the nearest reference point.

    `offset_s` is added to OpenNetIQ times (use it when the two clocks differ).
    Only LTE serving cells are graded: the exit criterion is LTE RSRP/RSRQ.
    """
    times = [p.time for p in reference]
    tol = timedelta(seconds=tolerance_s)
    diffs: dict[str, list[float]] = {m: [] for m in METRICS}
    matched = lte = pci_checked = pci_same = 0
    for row in onq_rows:
        if (row.get("serving_rat") or "") != "LTE":
            continue
        lte += 1
        at = parse_time(row.get("timestamp"))
        if at is None:
            continue
        ref = _nearest(reference, times, at + timedelta(seconds=offset_s), tol)
        if ref is None:
            continue
        matched += 1
        for metric, (col, _) in METRICS.items():
            ours, theirs = parse_float(row.get(col)), ref.values.get(metric)
            if ours is not None and theirs is not None:
                diffs[metric].append(ours - theirs)
        pci = (row.get("serving_pci_psc_bsic") or "").strip()
        if ref.pci and pci:
            pci_checked += 1
            pci_same += pci == ref.pci
    results = []
    for metric, (_, limit) in METRICS.items():
        d = diffs[metric]
        absolute = [abs(x) for x in d]
        results.append(
            MetricResult(
                metric=metric,
                pairs=len(d),
                median_abs_diff=median(absolute),
                mean_bias=sum(d) / len(d) if d else None,
                p90_abs_diff=percentile(absolute, 0.9),
                limit=limit,
            )
        )
    return RadioReport(
        onq_samples=len(onq_rows),
        lte_samples=lte,
        ref_points=len(reference),
        matched=matched,
        pci_checked=pci_checked,
        pci_agreement=pci_same / pci_checked if pci_checked else None,
        metrics=results,
    )
