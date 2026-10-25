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
| NICTA QoS Rule 2022 Appendix A/B per region and area, with sample counts (spec v3 M16) | `onq-validate report --rule nicta-qos-2022` |

- Procedure: [PROTOCOL.md](PROTOCOL.md). Results go in a copy of
  [RESULTS-TEMPLATE.md](RESULTS-TEMPLATE.md).
- Tool: `tests/field-validation/` (Python 3.11+, standard library only; Excel output needs `pip install -e .[xlsx]`).

```bash
cd tests/field-validation
pip install -e .            # or: python -m onq_validation ...
onq-validate radio --onq route1.csv --ref route1_gnettrack.csv \
  --profile gnettrack --ref-utc-offset 10
onq-validate throughput --onq route1_tests.csv --ref speed_reference.csv
onq-validate sampling --onq soak.csv --battery-start 100 --battery-end 78
onq-validate files --csv route1.csv --geojson route1.geojson
onq-validate --json results/radio.json radio ...   # machine-readable copy
onq-validate report exports/digicel/ --licensee "Digicel PNG" --period 2026H2 \
  --csv-dir results/digicel --xlsx results/digicel/nicta-qos-2026H2.xlsx
```

### NICTA QoS Rule 2022 report (`report`)
Reads every `*_voice_sms.csv`, `*_qoe.csv` and `*_tests.csv` under the given
files or folders (one operator per run). It groups rows by the sessions'
campaign tags (region × area class; untagged rows go under `(untagged)`) and
prints:

- **Appendix A** (Schedule 1): call attempts, failed (`not_placed`,
  `rejected`, `no_answer`, `setup_timeout`) → call failure rate; established
  (`completed` + `dropped`) and dropped → call drop rate; both ≤ 2 %. Also
  the mean setup time and the voice technologies seen. Calls without
  call-log data (`unknown`, `ended_early`) are excluded and counted.
- **Appendix B** (Schedule 2): FTP download ≥ 2.5 Mbps and upload
  ≥ 0.5 Mbps (share of samples ≥ 90 % from 2024, 80 % before; failed
  transfers count as samples not meeting it); ICMP ping probes ≤ 250 ms
  (lost probes count as not meeting it); web page load ≤ 10 s; RSRP
  ≥ −110 dBm (LTE) and RSCP ≥ −100 dBm (WCDMA) from the FTP downloads'
  serving level (each ≥ 80 %). Averages and shares to one decimal place.
  HTTP transfers and TCP/DNS probes are not used.
- **Sample counts**: ≥ 100 calls per region; per location ≥ 10 FTP
  downloads, ≥ 10 FTP uploads, ≥ 10 web tests and ≥ 100 ping probes;
  ≥ 30 locations per region.

`--period 2026H1|2026H2` keeps rows of that measurement period (UTC). Exit
status 1 when any requirement or sample count is not met.

Exit status 0 = pass, 1 = fail, 2 = bad input. Output is Markdown, ready to
paste into the results file.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md).
