# Latency Engine — Platform API

EventChannel `org.opennetiq/latency` (ADR-013). Listening runs one test; cancelling the subscription cancels it.

## Arguments
| Key | Type | Default | Notes |
|---|---|---|---|
| `host` | String | – | hostname or IP literal (no scheme/path) |
| `port` | int | 443 | TCP target port |
| `protocols` | List<String> | `[icmp, tcp, dns]` | order of execution |
| `probes` | int | 20 | 1..100 |
| `interval_ms` | int | 200 | 200..5000 |
| `timeout_ms` | int | 2000 | 100..10000 |

The DNS resolver is chosen natively (first resolver of the active network). Invalid arguments: error `INVALID_CONFIG`, then end of stream.

## Events
| `type` | Fields |
|---|---|
| `protocol` | `protocol` |
| `probe` | `protocol`, `seq` (1-based), `rtt_ms` (null = lost) |
| `result` | `protocol`, `method` (`lat-1.0`), `target`, `probes_sent`, `probes_received`, `min_ms`, `max_ms`, `mean_ms`, `median_ms`, `p95_ms`, `jitter_ms`, `packet_loss_pct`, `raw_rtts_ms` (list, null = lost), `status`, `error` |

Results arrive after the last protocol, then end of stream. Result keys equal the `latency_tests` columns (`raw_rtts_ms` stored as a JSON array; `error` is not stored in schema v1).

## Permissions
`ACCESS_NETWORK_STATE` (normal, install-time) to read the resolver address.
