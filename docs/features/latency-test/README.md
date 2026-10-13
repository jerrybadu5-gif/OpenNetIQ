# Latency Engine

ICMP, TCP and DNS round-trip times with jitter and packet loss, method `lat-1.0` (MEASUREMENT-METHODOLOGY.md §6). Closes #21.

## What it does
- **Home -> Latency test**: probes the test server configured on the Speed test screen. **Start** runs ICMP, then TCP, then DNS; **Cancel** stops at once and stores nothing.
- Per protocol: 20 probes, 200 ms apart, 2 s timeout. Results: min, max, mean, median, P95 (nearest rank), jitter (mean absolute difference of consecutive RTTs, RFC 3393 IPDV), packet loss %, and the raw RTT list (lost = `null`) for recomputation.
- **No root**: ICMP uses the system `ping` binary (Android allows 200 ms intervals without privileges); TCP measures `connect()`; DNS sends a standard A query over UDP to the phone's own resolver.
- Each protocol is one `latency_tests` row with `methodology_version`. Like the speed test, the run is linked to the open drive session or to a `single_test` session holding the start snapshot.
- Status: `ok` (all probes sent, at least one answer), `partial` (cut short), `failed` (no answer). ICMP is often filtered by mobile networks or servers: that shows as 100 % loss with the reason from `ping`.

## Targets
| Protocol | Target |
|---|---|
| ICMP | test server host |
| TCP | test server host and port from its URL (443 for HTTPS) |
| DNS | the active network's first DNS resolver, querying the test server host name (skipped for IP-literal servers) |

Charts and history come with #22.
