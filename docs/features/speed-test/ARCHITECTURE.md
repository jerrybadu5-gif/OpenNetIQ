# Speed Test Engine — Architecture

```
SpeedTestScreen ─> SpeedTestController (Notifier)
                     ├─ speedTestServerProvider  (app_settings / --dart-define)
                     ├─ SpeedTestEngine port ─> PlatformSpeedTestEngine ─ EventChannel org.opennetiq/speed
                     │                                                     │
                     │                         MeasurementBridge (Kotlin) ─┘
                     │                           SpeedTestEngine (OkHttp, worker threads)
                     │                             ByteSampler · ThroughputMath · SpeedTestConfig
                     ├─ radioSnapshotProvider / locationStatusProvider (kept alive by speedTestPipelineProvider)
                     └─ SpeedTestStore (Drift speed_tests) + SessionRepository/SampleRepository (snapshot)
```

## Kotlin (`measurement/speed/`)
| File | Role |
|---|---|
| `SpeedTestConfig` | Base URL validation, endpoints, method parameters, channel arguments |
| `SpeedTestEngine` | DNS timing, OkHttp client (HTTP/1.1, pool = streams, pre-resolved DNS, `Accept-Encoding: identity`), worker thread per stream, 100 ms sampler, cancel |
| `ByteSampler` | Atomic byte counter cut into measured-length intervals |
| `ThroughputMath` | Ramp-up exclusion, time-weighted mean, nearest-rank percentiles, 1 s peak window |
| `SpeedTestResult` | Status rule (>= 1 MB per valid direction) and channel map |

The engine is plain JVM: unit tests run it end to end against an in-process HTTP server (`LocalSpeedServer`).

## Timing definitions
- `dns_ms`: `InetAddress` lookup of the server host (system resolver).
- `tcp_connect_ms`: median over the test's connections of OkHttp `connectStart` -> `secureConnectStart` (HTTPS) or `connectEnd` (HTTP): TCP handshake only.
- Download bytes: counted as read from the socket. Upload bytes: counted as handed to the socket (sender side), as in LibreSpeed and Ookla-style HTTP tests.

## Cancel safety
Cancelling the Dart subscription calls `onCancel` -> `engine.cancel()`: all calls are cancelled, workers stop, the client pool is evicted; no event is emitted afterwards and nothing is stored.
