# Signal Monitor

Live serving- and neighbour-cell measurements for 2G, 3G, 4G, 5G NSA and 5G SA, refreshed every second.

Closes: #8 (platform contract, see ADR-013), #11 (LTE & NR), #12 (GSM & WCDMA), #13 (5G NSA/SA detection), #15 (Live Signal Dashboard).

## What it shows
- Operator, PLMN (MCC-MNC), network type (e.g. `5G NSA (5G)`), roaming and data state
- Serving cell: level (RSRP / SS-RSRP / RSCP / RSSI) with quality class, TAC/LAC, PCI/PSC/BSIC, Cell ID, eNB ID or gNB ID, (E/NR/U)ARFCN, band, bandwidth, RSRQ, SINR, RSSI, CQI, TA, CSI metrics
- In 5G NSA: LTE anchor and NR leg as separate cards
- One-minute level trend chart
- Neighbour cells sorted strongest first
- Warnings for stale/cached data and when 5G NSA cannot be detected

## Permissions
| Permission | Why | Without it |
|---|---|---|
| `ACCESS_FINE_LOCATION` | Android only returns cell info to apps with precise location | Monitor cannot start |
| `READ_PHONE_STATE` | Network type and 5G NSA detection (`TelephonyDisplayInfo`) | Cells still shown; network type `UNKNOWN`, NSA not detected |

Nothing is stored or uploaded by this feature. Storage arrives with issue #16, location with #14.

## Run
```powershell
cd apps\mobile
flutter run --flavor dev -t lib/main_dev.dart
```
Home -> **Signal monitor** -> **Grant access**.

## Known limits
- Android 10 (API 29): 5G NSA cannot be detected (no display-info API); shown as LTE.
- Many modems report the NSA NR leg as unregistered or not at all; the first NR cell is shown as the leg.
- gNB ID uses a 24-bit gNB-ID length by default; operators may use 22-32 bits (configurable in `RadioCollector`).
- CDMA and TD-SCDMA cells are ignored.
