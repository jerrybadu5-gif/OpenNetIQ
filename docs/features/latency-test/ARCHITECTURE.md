# Latency Engine — Architecture

```
LatencyTestScreen ─> LatencyTestController (Notifier)
                      ├─ speedTestServerProvider -> LatencyConfig.targetOf(url)
                      ├─ TestContextService (shared with the speed test)
                      │    awaitRadio · latestLocation · link(single_test | drive session)
                      ├─ LatencyEngine port ─> PlatformLatencyEngine ─ EventChannel org.opennetiq/latency
                      │                                                  │
                      │                       MeasurementBridge (Kotlin) ┘  dnsServer() from LinkProperties
                      │                         LatencyEngine: ICMP (ping process) · TCP (Socket.connect) · DNS (UDP)
                      │                         LatencyMath · PingOutput · DnsQuery · LatencyResult
                      └─ LatencyStore (Drift latency_tests, one transaction per run)
```

## Kotlin (`measurement/latency/`)
| File | Role |
|---|---|
| `LatencyConfig` | Method parameters, validation (host allow-list: no shell characters; interval >= 200 ms) |
| `LatencyEngine` | Runs protocols in order; probes on a fixed 200 ms schedule; cancel via latch + process destroy |
| `PingOutput` | `ping` argument list (no shell) and reply parsing by `icmp_seq` (handles loss, reordering, duplicates, `time<1`) |
| `DnsQuery` | RFC 1035 A query and response matching by ID |
| `LatencyMath` | Statistics, jitter over consecutive successful pairs, loss |

## Shared test context (Dart)
`features/recording/application/test_context.dart` (`TestContextService`, `testRadioWaitProvider`) now serves both the speed and latency tests: waiting for the start radio snapshot, the latest GNSS status, network-type tracking and the session link. `SpeedTestStatus` became `TestStatus` (`domain/entities/test_status.dart`), shared by both result types.
