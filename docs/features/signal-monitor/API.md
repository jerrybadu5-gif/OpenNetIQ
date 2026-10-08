# Signal Monitor - Platform Channel Contract (v1)

## MethodChannel `org.opennetiq/measurement`

| Method | Args | Returns |
|---|---|---|
| `getPermissionStatus` | - | `PermissionStatus` |
| `requestPermissions` | - | `PermissionStatus` after the Android dialog closes. Error `IN_PROGRESS` if a dialog is already showing |

`PermissionStatus`: `{location: bool, phone_state: bool, has_telephony: bool, api_level: int}`

## EventChannel `org.opennetiq/radio`

Listen arguments: `{interval_ms: int}` (clamped to 500-10000, default 1000).

Errors: `PERMISSION_DENIED` (no precise location / revoked), `NO_TELEPHONY`.

Event = `RadioSnapshot`:

| Key | Type | Notes |
|---|---|---|
| `timestamp` | string | UTC ISO 8601 ms, sample time |
| `radio_timestamp` | string? | Newest cell report time |
| `operator` | string? | Network operator name |
| `mcc`, `mnc` | string? | Serving PLMN |
| `sim_operator` | string? | SIM operator name |
| `network_type` | string | `samples.network_type` enum |
| `data_state` | string? | `CONNECTED`, `DISCONNECTED`, ... |
| `is_roaming` | bool? | |
| `quality_flag` | string? | `STALE`, `CACHED`, `NO_PHONE_STATE`, joined with `|` |
| `cells` | list | `CellObservation` maps |

`CellObservation` keys are exactly the `cell_observations` columns of DATA-DICTIONARY.md except ids:
`is_serving, rat, mcc, mnc, lac_tac, cell_id, enb_id, gnb_id, local_cell_id, pci_psc_bsic, arfcn, band, bandwidth_khz, rssi_dbm, rscp_dbm, ecno_db, rsrp_dbm, rsrq_db, sinr_db, cqi, timing_advance, csi_rsrp_dbm, csi_rsrq_db, csi_sinr_db, quality_flag`.
Integers on the wire; Dart maps dBm/dB to `double`. Missing = `null`, never 0.

Compatibility: Dart ignores unknown keys and skips cells with an unknown `rat`; wrong types raise `FormatException`.
