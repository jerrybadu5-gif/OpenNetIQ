# API: customer-experience tests (#29)

## MethodChannel `org.opennetiq/qoe`
| Method | Arguments | Result keys |
|---|---|---|
| `web` | `url`, `timeout_ms` | `dns_ms, connect_ms, tls_ms, ttfb_ms, dom_ms, total_ms, bytes, error` |
| `video` | `url`, `mode` (`stream`/`page`), `duration_ms` | `start_delay_ms, rebuffer_count, rebuffer_ms, played_ms, total_ms, bitrate_kbps, resolution, error` |
| `app` | `url`, `timeout_ms?` | `dns_ms, connect_ms, tls_ms, ttfb_ms, total_ms, http_status, bytes, error` |
| `file` | `server_url`, `size_mib`, `direction` | as `app` + `direction, rate_mbps` |
| `cancel` | – | ends the running test with `error: "cancelled"` |

`error == null` = success (video: playback started). Times in ms.

## Settings JSON (`app_settings` key `qoe.settings.v1`)
```json
{"web": [{"name": "Google", "url": "https://www.google.com/", "mode": "stream"}],
 "apps": [...], "videos": [{"name": "YouTube", "url": "https://…", "mode": "page"}],
 "file_size_mib": 5, "video_s": 30, "page_timeout_s": 30}
```

## Export `<base>_qoe.csv`
`test_id, session_id, measurement_id, timestamp, methodology_version, kind,
label, target, status, error, lat, lon, network_type, total_ms, dns_ms,
connect_ms, tls_ms, ttfb_ms, dom_ms, http_status, start_delay_ms,
rebuffer_count, rebuffer_ms, played_ms, bitrate_kbps, resolution, bytes,
rate_mbps, direction` (columns: DATA-DICTIONARY.md `qoe_tests`).
