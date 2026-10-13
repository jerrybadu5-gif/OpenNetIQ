# Architecture: field validation (#25)

Standalone Python package in `tests/field-validation/` (no app or backend
dependency, standard library only, so it runs on any laptop).

```
onq_validation/
  io.py          CSV reading, UTC time parsing (ISO or strptime + offset), median, nearest-rank percentile
  profiles.py    reference column profiles (generic, gnettrack) + --map overrides
  radio.py       LTE RSRP/RSRQ/SINR pairing (nearest within ±0.5 s) and statistics
  throughput.py  speed-test pairing (closest unused within 300 s), relative error
  sampling.py    duration, expected vs recorded samples, gaps, GNSS, battery drain
  files.py       structural checks of exported CSV / GeoJSON
  report.py      Markdown + JSON output
  cli.py         onq-validate subcommands
```

Design choices:
- Reads the app's **export files** (#23), not the database, so the same
  files that go to Excel/QGIS are the ones validated.
- Only **LTE serving cells** are graded for radio (the exit criterion);
  SINR is reported without a limit (vendors compute it differently).
- Statistics match the app (nearest-rank percentiles, median).
- CI: `.github/workflows/field-validation.yml` (ruff, pytest, coverage ≥ 80 %).
