# Speed Test Engine

Multi-connection HTTP throughput test, method `http-mc-1.0` (MEASUREMENT-METHODOLOGY.md §5, ADR-007). Closes #19.

## What it does
- **Home -> Speed test**: set the test-server URL once, then **Start test**. Shows the phase and the rate over the last second; **Cancel** stops at once.
- Engine in Kotlin (OkHttp): DNS lookup timed, 4 parallel HTTP/1.1 connections, 12 s per direction (2 s ramp-up discarded, 10 s measured), bytes sampled every 100 ms.
- Results: mean, median, P10, P90, peak (best 1 s) in Mbit/s (SI), bytes transferred, DNS time, median TCP connect time, status `ok` / `partial` / `failed` with the reason.
- **Radio snapshot linked**: the radio + GPS state at the start is stored as a sample; the result row references it. During a drive test the result is linked to the open session's latest sample; otherwise a `single_test` session is created to hold the snapshot.
- **RAT change**: if the network type differs between start, phase changes and end, `rat_changed` is set (flagged, not dropped).
- Every result stores `method` and `methodology_version`. Cancelled tests store nothing.
- The full test screen (live curve, history, server settings) follows in #22; the production server container in #20.

## Test server
The app expects LibreSpeed-compatible endpoints under a base URL: `garbage.php?ckSize=N` and `empty.php`.

| Use | Server |
|---|---|
| Development on a LAN | `python scripts/speedtest_dev_server.py --port 8080` then `http://<PC IP>:8080/backend/` (dev flavor allows plain HTTP) |
| Regulatory measurements | Self-hosted container (#20), HTTPS, >= 1 Gbps uplink, in-country |

A build-time default can be set with `--dart-define=ONQ_SPEEDTEST_URL=https://.../backend/`.

**Data use:** a test moves (download + upload rate) x 10 s plus ramp-up; at 100 Mbit/s that is about 300 MB. The screen warns about this.
