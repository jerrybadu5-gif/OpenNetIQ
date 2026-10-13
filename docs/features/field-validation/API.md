# API: field validation (#25)

## Inputs
| Command | `--onq` | `--ref` |
|---|---|---|
| `radio` | samples CSV (`timestamp`, `serving_rat`, `serving_rsrp_dbm`, `serving_rsrq_db`, `serving_sinr_db`, `serving_pci_psc_bsic`) | radio log; profile `generic` (`timestamp`, `rsrp_dbm`, `rsrq_db`, `sinr_db`, `pci`) or `gnettrack` (`Timestamp` `%Y.%m.%d_%H.%M.%S`, `Level`, `Qual`, `SNR`) |
| `throughput` | `*_tests.csv` (`test_type=speed`, `status` ok/partial, `dl_mean_mbps`, `ul_mean_mbps`) | `timestamp, dl_mbps, ul_mbps` (override with `--map time= dl= ul= time_format=`) |
| `sampling` | samples CSV (`timestamp`, `lat`, `h_accuracy_m`) | – |
| `files` | `--csv` / `--geojson` (repeatable) | – |

Times: ISO 8601 with zone, or naive + `--ref-utc-offset H` (subtracted).
`--offset S` shifts OpenNetIQ times when clocks differ.

## Definitions
- Radio diff = OpenNetIQ − reference (dB). Pass: median |diff| ≤ 2 dB for
  RSRP and RSRQ, at least one pair each.
- Throughput rel. diff = (OpenNetIQ − reference) / reference. Pass: median
  |rel diff| ≤ 10 % per direction and ≥ 30 pairs.
- Missing % = 1 − samples / (duration / interval + 1). Pass: duration ≥ 2 h
  and missing ≤ 1 %. Gap = step > 1.5 × interval.
- Battery drain = (start % − end %) / hours. Pass: ≤ 15 %/h.

## Outputs
Markdown on stdout; `--json FILE` writes the same results (dataclasses plus
`passed` flags). Exit 0 pass, 1 fail, 2 input error.
