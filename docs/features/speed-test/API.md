# Speed Test Engine — Platform API

EventChannel `org.opennetiq/speed` (ADR-013). Listening starts one test; cancelling the subscription cancels it.

## Arguments
| Key | Type | Default | Notes |
|---|---|---|---|
| `server_url` | String | – | http(s) base URL; `/` appended if missing |
| `streams` | int | 4 | 1..16 |
| `direction_ms` | int | 12000 | per direction incl. 2 s ramp-up, 1000..60000 |

Invalid arguments: error `INVALID_CONFIG`, then end of stream.

## Events
| `type` | Fields |
|---|---|
| `phase` | `phase`: `dns`, `download`, `upload` |
| `progress` | `phase`, `elapsed_ms`, `mbps` (last 1 s), every 100 ms |
| `result` | `status` (`ok`/`partial`/`failed`), `method`, `server_host`, `streams`, `dns_ms`, `tcp_connect_ms`, `dl_mean_mbps`, `dl_median_mbps`, `dl_p10_mbps`, `dl_p90_mbps`, `dl_peak_mbps`, `dl_bytes`, `ul_*` (same), `error` |

`result` keys equal the `speed_tests` columns (DATA-DICTIONARY.md). A direction without valid data has all its keys `null`.

## Server endpoints (LibreSpeed-compatible)
| Endpoint | Method | Behaviour |
|---|---|---|
| `garbage.php?ckSize=N&r=…` | GET | N MiB of incompressible data (engine asks for 100) |
| `empty.php?r=…` | POST | Discards the body (engine sends 16 MiB per request) |

## Settings
`app_settings.key = speedtest.server_url`.
