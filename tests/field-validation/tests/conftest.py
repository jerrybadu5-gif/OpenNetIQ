import csv
import json
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

T0 = datetime(2026, 10, 13, 1, 0, 0, tzinfo=UTC)


def iso(t: datetime) -> str:
    return t.strftime("%Y-%m-%dT%H:%M:%S.") + f"{t.microsecond // 1000:03d}Z"


def write_csv(path: Path, header: list[str], rows: list[list[object]]) -> Path:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\r\n")
        w.writerow(header)
        for r in rows:
            w.writerow(["" if v is None else v for v in r])
    return path


SAMPLE_HEADER = [
    "measurement_id",
    "timestamp",
    "lat",
    "lon",
    "h_accuracy_m",
    "network_type",
    "operator",
    "device_model",
    "methodology_version",
    "serving_rat",
    "serving_pci_psc_bsic",
    "serving_rsrp_dbm",
    "serving_rsrq_db",
    "serving_sinr_db",
]


def sample_row(
    i: int, t: datetime, rsrp=-90.0, rsrq=-10.0, sinr=12.0, rat="LTE", pci=101, fix=True
):
    return [
        f"m{i}",
        iso(t),
        -9.44 if fix else None,
        147.18 if fix else None,
        4.0 if fix else None,
        "LTE" if rat == "LTE" else "NR_SA",
        "Digicel",
        "SM-A546E",
        "1.0.0",
        rat,
        pci,
        rsrp,
        rsrq,
        sinr,
    ]


@pytest.fixture
def samples_csv(tmp_path):
    def make(rows, name="samples.csv"):
        return write_csv(tmp_path / name, SAMPLE_HEADER, rows)

    return make


@pytest.fixture
def geojson(tmp_path):
    def make(doc, name="track.geojson"):
        p = tmp_path / name
        p.write_text(json.dumps(doc) if not isinstance(doc, str) else doc, encoding="utf-8")
        return p

    return make


def seconds(n: float) -> timedelta:
    return timedelta(seconds=n)
