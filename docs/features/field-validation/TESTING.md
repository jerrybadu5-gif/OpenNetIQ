# Testing: field validation (#25)

## Automated
```bash
cd tests/field-validation
pip install -e ".[dev]"
ruff check . && ruff format --check .
pytest --cov=onq_validation --cov-fail-under=80
```
21 tests, 97 % coverage: parsing (ISO/strptime/offsets, empty ≠ 0), profiles
and overrides, radio pairing (tolerance, offset, non-LTE, PCI, no pairs ≠
pass), throughput (n ≥ 30, ±10 %, window), sampling (gaps, missing %,
battery), file checks (ragged rows, `null` cells, swapped lat/lon, invalid
geometry), CLI exit codes, JSON output and help text.

## Dry run before driving
1. Record a 5-minute walk with OpenNetIQ and the reference app on one phone.
2. Export both; run `onq-validate radio` — expect matches > 0 and a PASS or
   a small, explainable difference. Fix column mapping now, not after the
   drive.

- `tests/test_nicta.py`: Appendix A/B on synthetic exports with hand-calculated rates, period filter and 80/90 % share by year, untagged rows, sample-count shortfalls, CLI Markdown/CSV/Excel/JSON outputs.
