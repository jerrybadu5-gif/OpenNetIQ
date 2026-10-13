"""Markdown and JSON renderings of the check results."""

from __future__ import annotations

import json
from dataclasses import asdict, is_dataclass
from typing import Any

from .radio import RadioReport
from .sampling import SamplingReport
from .throughput import LIMIT, MIN_PAIRS, ThroughputReport


def verdict(passed: bool | None) -> str:
    return {True: "PASS", False: "FAIL", None: "n/a"}[passed]


def _num(value: float | None, digits: int = 2, suffix: str = "") -> str:
    return "-" if value is None else f"{value:.{digits}f}{suffix}"


def radio_md(r: RadioReport) -> str:
    lines = [
        f"## Radio agreement: {verdict(r.passed)}",
        "",
        f"OpenNetIQ samples {r.onq_samples} (LTE {r.lte_samples}), reference points "
        f"{r.ref_points}, matched {r.matched}"
        + ("" if r.pci_agreement is None else f", PCI agreement {r.pci_agreement:.1%}")
        + ".",
        "",
        "| Metric | Pairs | Median abs diff (dB) | Bias (dB) | P90 abs (dB) | Limit | Result |",
        "|---|---|---|---|---|---|---|",
    ]
    for m in r.metrics:
        lines.append(
            f"| {m.metric.upper()} | {m.pairs} | {_num(m.median_abs_diff)} | "
            f"{_num(m.mean_bias)} | {_num(m.p90_abs_diff)} | "
            f"{'-' if m.limit is None else f'±{m.limit:g}'} | {verdict(m.passed)} |"
        )
    return "\n".join(lines)


def throughput_md(r: ThroughputReport) -> str:
    lines = [
        f"## Throughput agreement: {verdict(r.passed)}",
        "",
        f"OpenNetIQ tests {r.onq_tests}, reference tests {r.ref_tests}, matched {r.matched}. "
        f"Limit ±{LIMIT:.0%} median, n >= {MIN_PAIRS}.",
        "",
        "| Direction | Pairs | Median abs rel diff | Mean bias | Result |",
        "|---|---|---|---|---|",
    ]
    for d in r.directions:
        lines.append(
            f"| {d.direction} | {d.pairs} | {_num(_pct(d.median_abs_rel_diff), 1, ' %')} | "
            f"{_num(_pct(d.mean_rel_bias), 1, ' %')} | {verdict(d.passed)} |"
        )
    return "\n".join(lines)


def _pct(value: float | None) -> float | None:
    return None if value is None else value * 100


def sampling_md(r: SamplingReport) -> str:
    lines = [
        f"## Sampling: {verdict(r.sampling_passed)}",
        "",
        f"- Duration {r.duration_h:.2f} h (>= 2 h), interval {r.interval_s:g} s",
        f"- Samples {r.samples} of {r.expected} expected, missing {r.missing_pct:.2f} % (<= 1 %)",
        f"- GNSS fix in {r.fix_pct:.1f} % of samples, median accuracy "
        f"{_num(r.median_h_accuracy_m, 1, ' m')}",
        f"- Gaps > 1.5 x interval: {len(r.gaps)}",
    ]
    for g in r.gaps[:10]:
        lines.append(f"  - {g.start} -> {g.end} ({g.seconds:.0f} s)")
    if len(r.gaps) > 10:
        lines.append(f"  - ... {len(r.gaps) - 10} more")
    lines += [
        "",
        f"## Battery: {verdict(r.battery_passed)}",
        "",
        f"- Drain {_num(r.battery_drain_pct_per_h, 1, ' %/h')} (<= 15 %/h)",
    ]
    return "\n".join(lines)


def files_md(results: dict[str, list[str]]) -> str:
    ok = all(not p for p in results.values())
    lines = [f"## Export files: {verdict(ok)}", ""]
    for name, problems in results.items():
        lines.append(f"- `{name}`: {'OK' if not problems else ''}")
        lines += [f"  - {p}" for p in problems]
    return "\n".join(lines)


def _plain(value: Any) -> Any:
    if is_dataclass(value) and not isinstance(value, type):
        data = asdict(value)
        for attr in ("passed", "sampling_passed", "battery_passed"):
            if hasattr(value, attr):
                data[attr] = getattr(value, attr)
        return data
    return value


def to_json(results: dict[str, Any]) -> str:
    return json.dumps({k: _plain(v) for k, v in results.items()}, indent=2, default=str)
