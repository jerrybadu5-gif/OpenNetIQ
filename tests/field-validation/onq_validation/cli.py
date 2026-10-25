"""`onq-validate`: M1 field-validation checks.

Exit status: 0 all graded checks pass, 1 a check fails, 2 bad input.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

from . import files, nicta, radio, report, sampling, throughput
from .io import read_csv
from .profiles import PROFILES, parse_overrides


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="onq-validate", description=__doc__)
    p.add_argument("--json", type=Path, help="also write results as JSON")
    sub = p.add_subparsers(dest="command", required=True)

    r = sub.add_parser("radio", help="RSRP/RSRQ vs a reference log (±2 dB median)")
    r.add_argument("--onq", required=True, type=Path, help="OpenNetIQ samples CSV")
    r.add_argument("--ref", required=True, type=Path, help="reference radio log CSV")
    r.add_argument("--profile", choices=sorted(PROFILES), default="generic")
    r.add_argument(
        "--map",
        action="append",
        metavar="FIELD=COLUMN",
        help="override a column: time, time_format, rsrp, rsrq, sinr, pci",
    )
    r.add_argument(
        "--ref-utc-offset",
        type=float,
        default=0,
        help="hours to subtract from naive reference times (PNG: 10)",
    )
    r.add_argument("--tolerance", type=float, default=0.5, help="max time gap, s")
    r.add_argument("--offset", type=float, default=0, help="added to OpenNetIQ times, s")

    t = sub.add_parser("throughput", help="DL/UL vs reference tests (±10 %%, n >= 30)")
    t.add_argument("--onq", required=True, type=Path, help="OpenNetIQ *_tests.csv")
    t.add_argument(
        "--ref", required=True, type=Path, help="reference CSV: timestamp, dl_mbps, ul_mbps"
    )
    t.add_argument(
        "--map", action="append", metavar="FIELD=COLUMN", help="override: time, time_format, dl, ul"
    )
    t.add_argument("--ref-utc-offset", type=float, default=0)
    t.add_argument("--window", type=float, default=300, help="max pairing gap, s")

    s = sub.add_parser("sampling", help="duration, missing samples, battery")
    s.add_argument("--onq", required=True, type=Path, help="OpenNetIQ samples CSV")
    s.add_argument("--interval", type=float, default=1.0, help="sampling interval, s")
    s.add_argument("--battery-start", type=float, help="battery %% at start")
    s.add_argument("--battery-end", type=float, help="battery %% at end")

    rp = sub.add_parser("report", help="NICTA QoS Rule 2022 Appendix A/B tables from app exports")
    rp.add_argument("exports", nargs="+", type=Path, help="export CSVs or folders (recursive)")
    rp.add_argument("--rule", choices=[nicta.RULE], default=nicta.RULE)
    rp.add_argument("--licensee", default="(licensee)", help="operator name for the title")
    rp.add_argument("--period", help="measurement period, e.g. 2026H2 (default: all data)")
    rp.add_argument("--csv-dir", type=Path, help="write the tables as CSV files here")
    rp.add_argument("--xlsx", type=Path, help="write an Excel workbook (needs openpyxl)")

    f = sub.add_parser("files", help="exports open cleanly (structure checks)")
    f.add_argument("--csv", type=Path, action="append", default=[], help="samples CSV")
    f.add_argument("--geojson", type=Path, action="append", default=[])
    return p


def run(argv: list[str]) -> tuple[int, str, dict[str, Any]]:
    args = _parser().parse_args(argv)
    if args.command == "radio":
        profile = PROFILES[args.profile].with_overrides(parse_overrides(args.map))
        ref = radio.load_reference(read_csv(args.ref), profile, args.ref_utc_offset)
        if not ref:
            raise ValueError(f"no reference rows with a readable '{profile.time}' column")
        result = radio.compare(read_csv(args.onq), ref, args.tolerance, args.offset)
        return (0 if result.passed else 1), report.radio_md(result), {"radio": result}
    if args.command == "throughput":
        cols = {"time": "timestamp", "dl": "dl_mbps", "ul": "ul_mbps", "time_format": None}
        cols.update(parse_overrides(args.map))
        ref = throughput.load_reference(
            read_csv(args.ref),
            cols["time"],
            cols["dl"],
            cols["ul"],
            cols["time_format"],
            args.ref_utc_offset,
        )
        result = throughput.compare(read_csv(args.onq), ref, args.window)
        return (0 if result.passed else 1), report.throughput_md(result), {"throughput": result}
    if args.command == "sampling":
        result = sampling.analyse(
            read_csv(args.onq), args.interval, args.battery_start, args.battery_end
        )
        ok = result.sampling_passed and result.battery_passed is not False
        return (0 if ok else 1), report.sampling_md(result), {"sampling": result}
    if args.command == "report":
        period = nicta.Period.parse(args.period) if args.period else None
        rep = nicta.build(nicta.find_exports(args.exports), args.licensee, period)
        notes = []
        if args.csv_dir:
            notes += [f"wrote {p}" for p in nicta.write_csvs(rep, args.csv_dir)]
        if args.xlsx:
            notes.append(f"wrote {nicta.write_xlsx(rep, args.xlsx)}")
        text = nicta.markdown(rep) + ("\n\n" + "\n".join(notes) if notes else "")
        return (0 if rep.passed else 1), text, {"report": rep}
    checked = {str(p): files.check_csv(p) for p in args.csv}
    checked |= {str(p): files.check_geojson(p) for p in args.geojson}
    if not checked:
        raise ValueError("give at least one --csv or --geojson")
    ok = all(not v for v in checked.values())
    return (0 if ok else 1), report.files_md(checked), {"files": checked}


def main(argv: list[str] | None = None) -> int:
    try:
        code, markdown, data = run(sys.argv[1:] if argv is None else argv)
    except (OSError, ValueError, KeyError) as e:
        print(f"onq-validate: {e}", file=sys.stderr)
        return 2
    print(markdown)
    args = _parser().parse_args(sys.argv[1:] if argv is None else argv)
    if args.json:
        args.json.write_text(report.to_json(data), encoding="utf-8")
    return code


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
