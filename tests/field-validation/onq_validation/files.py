"""Exit criterion: CSV and GeoJSON open cleanly in Excel and QGIS.

Structural checks that catch what breaks those tools: ragged rows, missing
columns, literal "null"/"NaN" cells, invalid GeoJSON geometry or WGS 84
coordinates out of range.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

REQUIRED_SAMPLE_COLUMNS = (
    "measurement_id",
    "timestamp",
    "lat",
    "lon",
    "network_type",
    "operator",
    "device_model",
    "methodology_version",
)
BAD_CELLS = {"null", "none", "nan", "undefined"}


def check_csv(path: str | Path, required: tuple[str, ...] = REQUIRED_SAMPLE_COLUMNS) -> list[str]:
    problems: list[str] = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    if not rows:
        return ["empty file"]
    header = rows[0]
    problems += [f"missing column {c}" for c in required if c not in header]
    if len(set(header)) != len(header):
        problems.append("duplicate column names")
    for n, row in enumerate(rows[1:], start=2):
        if len(row) != len(header):
            problems.append(f"line {n}: {len(row)} fields, header has {len(header)}")
        bad = [c for c in row if c.strip().lower() in BAD_CELLS]
        if bad:
            problems.append(f"line {n}: literal {bad[0]!r} instead of an empty cell")
        if len(problems) > 20:
            problems.append("... more problems not listed")
            break
    return problems


def _check_position(coords: object, where: str) -> list[str]:
    if not isinstance(coords, list) or len(coords) not in (2, 3):
        return [f"{where}: position must be [lon, lat] or [lon, lat, alt]"]
    if not all(isinstance(c, int | float) for c in coords):
        return [f"{where}: non-numeric coordinate"]
    lon, lat = coords[0], coords[1]
    if not (-180 <= lon <= 180 and -90 <= lat <= 90):
        return [f"{where}: out of WGS 84 range (lat/lon swapped?)"]
    return []


def check_geojson(path: str | Path) -> list[str]:
    try:
        doc = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return [f"not valid JSON: {e}"]
    if not isinstance(doc, dict) or doc.get("type") != "FeatureCollection":
        return ["root is not a FeatureCollection"]
    problems: list[str] = []
    for i, f in enumerate(doc.get("features") or []):
        where = f"feature {i}"
        if not isinstance(f, dict) or f.get("type") != "Feature":
            problems.append(f"{where}: not a Feature")
            continue
        props = f.get("properties")
        if not isinstance(props, dict) or "feature_type" not in props:
            problems.append(f"{where}: no properties.feature_type")
        geom = f.get("geometry")
        if geom is None:
            continue
        kind = geom.get("type") if isinstance(geom, dict) else None
        coords = geom.get("coordinates") if isinstance(geom, dict) else None
        if kind == "Point":
            problems += _check_position(coords, where)
        elif kind == "LineString":
            if not isinstance(coords, list) or len(coords) < 2:
                problems.append(f"{where}: LineString needs >= 2 positions")
            else:
                for p in coords:
                    problems += _check_position(p, where)
        else:
            problems.append(f"{where}: unexpected geometry {kind!r}")
        if len(problems) > 20:
            problems.append("... more problems not listed")
            break
    return problems
