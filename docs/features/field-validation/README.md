# Field validation (issue #25)

Tools and protocol to prove the M1 exit criteria (ROADMAP Phase 1) with
real drives in Port Moresby before `v0.1.0`.

| Exit criterion | How it is checked |
|---|---|
| RSRP/RSRQ within ±2 dB median absolute difference vs reference, same device model | `onq-validate radio` |
| DL/UL within ±10 % of reference test, same server and place, n ≥ 30 | `onq-validate throughput` |
| 1 s sampling ≥ 2 h, screen off, ≤ 1 % missing | `onq-validate sampling` |
| Battery ≤ 15 %/h during passive logging | `onq-validate sampling --battery-start/--battery-end` |
| CSV and GeoJSON open cleanly in Excel and QGIS | `onq-validate files` + manual open |
| Crash-free sessions, signed release | release work (#26) |

- Procedure: [PROTOCOL.md](PROTOCOL.md). Results go in a copy of
  [RESULTS-TEMPLATE.md](RESULTS-TEMPLATE.md).
- Tool: `tests/field-validation/` (Python 3.11+, standard library only).

```bash
cd tests/field-validation
pip install -e .            # or: python -m onq_validation ...
onq-validate radio --onq route1.csv --ref route1_gnettrack.csv \
  --profile gnettrack --ref-utc-offset 10
onq-validate throughput --onq route1_tests.csv --ref speed_reference.csv
onq-validate sampling --onq soak.csv --battery-start 100 --battery-end 78
onq-validate files --csv route1.csv --geojson route1.geojson
onq-validate --json results/radio.json radio ...   # machine-readable copy
```

Exit status 0 = pass, 1 = fail, 2 = bad input. Output is Markdown, ready to
paste into the results file.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md).
