# Location - Platform Channel Contract (v1)

EventChannel `org.opennetiq/location`. Listen arguments: `{interval_ms: int}` (500-10000, default 1000).

Errors: `PERMISSION_DENIED`, `NO_GNSS` (no GPS receiver).

Event = `LocationStatus`:

| Key | Type | Notes |
|---|---|---|
| `timestamp` | string | UTC ISO 8601 ms, tick time |
| `provider_enabled` | bool | GPS provider switched on |
| `gps_quality` | string | `GOOD`, `POOR`, `NONE` |
| `fix_age_ms` | int? | Age of `fix` at tick time |
| `satellites_used` | int? | Satellites used in the fix |
| `satellites_visible` | int? | Satellites tracked |
| `fix` | map? | `LocationFix`, null when `gps_quality = NONE` |

`LocationFix`: `fix_time` (UTC ISO 8601), `lat`, `lon` (WGS84 degrees), `altitude_m`, `speed_mps`, `bearing_deg`, `h_accuracy_m`, `v_accuracy_m` (doubles, null when not reported), `provider` (string), `is_mock` (bool).

Keys match the `samples` columns of DATA-DICTIONARY.md; `is_mock` is stored as `quality_flag = MOCK_LOCATION`.
