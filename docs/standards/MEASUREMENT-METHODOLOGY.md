# Measurement Methodology — v1.0.0

`methodology_version = 1.0.0` · Applies to Phase 1 (M1). Changes require an ADR (ADR-009).

## 1. Sampling
| Item | Value |
|---|---|
| Drive-test sampling interval | 1 s (default), 2 s, 5 s |
| Radio refresh | `TelephonyManager.requestCellInfoUpdate()` per tick; cell data older than 2 s flagged `STALE` |
| GNSS | `GPS_PROVIDER`, 1 Hz; fix age > 2 s or accuracy > 50 m → `gps_quality = POOR` |
| Clock | Device UTC; each sample stores `timestamp` (sample time) and `radio_timestamp` (CellInfo timestamp) |
| Gaps | Consecutive samples more than 1.5 x interval apart, after removing user pauses, form a gap; missing ticks = round(step / interval) - 1. Completeness = recorded / (recorded + missing) |
| Interrupted sessions | A session open when the process died is closed as `aborted`, `ended_at` = last sample |

## 2. Radio metrics (raw, as reported by Android)
| Metric | RAT | Unit | Valid range (3GPP reporting) | Source API |
|---|---|---|---|---|
| RSSI | GSM | dBm | −113 … −51 | `CellSignalStrengthGsm.getRssi()` |
| RSCP | WCDMA | dBm | −120 … −24 | `CellSignalStrengthWcdma.getDbm()` |
| Ec/No | WCDMA | dB | −24 … 1 | `getEcNo()` (API 30) |
| RSRP | LTE | dBm | −140 … −43 (TS 36.133) | `CellSignalStrengthLte.getRsrp()` |
| RSRQ | LTE | dB | −34 … 3 | `getRsrq()` |
| SINR (RS-SNR) | LTE | dB | −20 … 30 | `getRssnr()` |
| RSSI | LTE | dBm | −113 … −51 | `getRssi()` (API 29) |
| CQI | LTE | index | 0 … 15 | `getCqi()` |
| Timing Advance | LTE | Ts units | 0 … 1282 | `getTimingAdvance()` |
| SS-RSRP | NR | dBm | −156 … −31 (TS 38.133) | `CellSignalStrengthNr.getSsRsrp()` |
| SS-RSRQ | NR | dB | −43 … 20 | `getSsRsrq()` |
| SS-SINR | NR | dB | −23 … 40 | `getSsSinr()` |
| CSI-RSRP / RSRQ / SINR | NR | dBm/dB | per TS 38.215 | `getCsiRsrp()` etc. |

Rules: `UNAVAILABLE` (Integer.MAX_VALUE) or out-of-range → `NULL` with `quality_flag`. Values are **never** clamped.

## 3. Cell identity derivations
- LTE: `enb_id = eci >> 8`, `local_cell_id = eci & 0xFF` (28-bit ECI, TS 36.413).
- NR: `gnb_id = nci >> (36 − gnb_id_length)`, default `gnb_id_length = 24` (configurable 22–32 per operator, TS 38.413).
- `network_type` enum: `GSM, GPRS, EDGE, UMTS, HSPA, HSPAP, LTE, LTE_CA, NR_NSA, NR_NSA_MMWAVE, NR_SA, UNKNOWN, NONE`.

## 4. Signal quality classes (display only, not regulatory thresholds)
Each RAT is classified on its main level metric. Lower bound inclusive.

| Class | LTE RSRP / NR SS-RSRP (dBm) | WCDMA RSCP (dBm) | GSM RSSI (dBm) | LTE/NR SINR (dB) |
|---|---|---|---|---|
| Excellent | ≥ −80 | ≥ −75 | ≥ −70 | ≥ 20 |
| Good | −90 … < −80 | −85 … < −75 | −80 … < −70 | 13 … < 20 |
| Fair | −100 … < −90 | −95 … < −85 | −90 … < −80 | 0 … < 13 |
| Poor | −110 … < −100 | −105 … < −95 | −100 … < −90 | < 0 |
| No service | < −110 | < −105 | < −100 | — |

Regulatory coverage thresholds are configured per jurisdiction in Phase 4 (e.g., licence condition ≥ −105 dBm outdoor).

## 4a. Quality flags
| Level | Flag | Meaning |
|---|---|---|
| Cell | `UNAVAILABLE` | The RAT's main level metric was not reported |
| Cell | `OUT_OF_RANGE` | A metric was outside its valid range and stored as NULL |
| Snapshot | `STALE` | Newest cell report older than 2 s |
| Snapshot | `CACHED` | `requestCellInfoUpdate` failed; cached `getAllCellInfo` used |
| Snapshot | `NO_PHONE_STATE` | READ_PHONE_STATE not granted: network type and 5G NSA not detectable |
| Sample | `MOCK_LOCATION` | Android reported a mock-location provider; excluded from regulatory statistics |
| Sample | `NO_GPS_FIX` | `gps_quality = NONE` (no fix, fix older than 30 s, or Location switched off) |

Multiple flags are sorted and joined with `|`.

## 5. Throughput (HTTP multi-connection, method `http-mc-1.0`)
1. Resolve server hostname → record `dns_ms`. Open 4 TCP connections → record median `tcp_connect_ms`.
2. Download: each stream GETs a large object for 10 s. Bytes counted every 100 ms across streams.
3. Discard first 2 s (TCP slow-start). Remaining 80 intervals → `mean_mbps`, `median_mbps`, `p10_mbps`, `p90_mbps`; `peak_mbps` = max 1 s rolling window (burst).
4. Upload: same with POST of random incompressible payload.
5. Mbps = bits / 10⁶ / s (SI). Application-layer goodput (excludes TCP/IP headers).
   Clarifications (no change to method v1.0): `mean` is time-weighted (bytes / time over the measured window); `median`, `p10`, `p90` are nearest-rank percentiles of the per-100 ms rates; `tcp_connect_ms` is the TCP handshake only (before TLS); connections use HTTP/1.1 so that 4 streams are 4 TCP connections; upload bytes are counted when handed to the socket.
6. Test invalid if: radio RAT changes mid-test (flagged, not dropped), < 1 MB transferred, or server error.

## 6. Latency (method `lat-1.0`)
- ICMP: 20 echo requests, 200 ms interval, 56-byte payload, 2 s timeout.
- TCP: 20 connects to server port 443, RTT = SYN→SYN/ACK as seen by connect().
- KPIs: `min, max, mean, median, p95` (nearest-rank), `jitter_ms = mean(|RTTᵢ − RTTᵢ₋₁|)` over successful consecutive probes (IPDV, RFC 3393), `packet_loss_pct = lost / sent × 100`.
- DNS: 20 standard A queries (recursion desired) over UDP/53 to the active network's first resolver, for the test server host name; RTT = send to matching response (any RCODE); 2 s timeout.
- Targets: ICMP and TCP probe the speed-test server host (TCP on its URL port). Probes are sent on a fixed 200 ms schedule; a probe without answer within the timeout is lost.
- ICMP uses the system `ping` (no root); replies are matched by sequence number, duplicates ignored.

## 6b. Customer-experience tests (method `qoe-1.0`, issue #29)
All probes start cold: no HTTP cache, no connection reuse, so DNS, TCP and TLS are measured as a first visit. Results are linked to the drive (or a stand-alone session) at the run start; each target is one `qoe_tests` row.
- **Web browsing**: page loaded in an off-screen Android WebView with an empty cache; W3C Navigation Timing gives DNS, TCP connect (TLS excluded), TLS, time to first byte, DOMContentLoaded and load-event end (page load time). Timeout 30 s (failed). Values come from the browser engine (Chromium), as experienced by users.
- **App reachability**: HTTPS GET of the app's endpoint (OkHttp, whole body read): DNS, TCP, TLS, first byte, total, HTTP status. HTTP ≥ 400 or no response = failed. Measures the network path to the service, not the app's own protocol.
- **Video streaming**, 30 s by default:
  - *Direct stream* (HLS/DASH/MP4): ExoPlayer with adaptive bitrate, no rendering surface. *Video on a web page* (YouTube, Facebook, game streams): first HTML5 `<video>` in a WebView shown on screen during the test (off-screen in the background), kept playing muted; progress polled every 500 ms (advancing = playing, no progress ≥ 1 s = rebuffer). Pre-roll ads count as playback.
  - Start delay = test start → first playback; rebuffer = playback → buffering after the first start, until playback resumes (an open stall counts until the end); played time; time-weighted bitrate of the selected video format (direct streams); highest resolution seen.
  - Status: no playback = failed; playback with a later error = partial.
- **File transfer**: fixed size (default 5 MiB) download from `garbage.php` and upload to `empty.php` of the configured test server, one connection; rate = bytes × 8 / total time (Mbit/s, SI). Complements the multi-connection speed test with a single-transfer user experience.
- Third-party sites see the phone's IP address; targets and video sources are configured by the operator of the test campaign.

## 6c. Voice call and SMS tests (method `vs-1.0`, issue #30)
KPI names follow ETSI TS 102 250-2 (telephony, SMS). Tests run only with the `voice_sms` consent, to numbers the campaign configures; each call or SMS is one `voice_sms_tests` row, linked like the other tests.
- **Voice call (mobile originated)**: `TelecomManager.placeCall` to the test line; the call is kept for the *call window* (default 45 s) counted from dialling, then released by the app. Call state is polled every 200 ms (`isInCall`). Answer time is not visible to non-dialer apps, so after release the connected duration is read from the call log (latest outgoing call since dialling; DATE/TYPE/DURATION only) and:
  - *setup time* = dialling → release − connected duration (1 s resolution of the call log; ≥ 0);
  - **completed**: connected > 0 and released by the app at the window end (`ok`);
  - **dropped**: connected > 0 but ended before the window by the network or far end (`failed`, `dropped = 1`) — use a test line that answers automatically and holds the call;
  - **no_answer** (released by the app, never connected) / **rejected** (ended by the network/far end, never connected) / **not_placed** (no call within 10 s): setup failures (`failed`);
  - call log unreadable: `partial` (`unknown` / `ended_early`), setup time NULL.
  - Ratios for reports: call setup success ratio = connected / attempted; call drop ratio = dropped / connected.
- **SMS**: one tagged message (`OpenNetIQ test ONQxxxxxx`) via `SmsManager` with sent and delivery reports; times from submission: *send_ms* (sent report), *delivery_ms* (status report, TP-Status < 0x20 = delivered), *receive_ms* (arrival of the same token, loopback targets only = end-to-end delivery time). Timeout default 60 s.
  - Loopback (`| self` target): `received` = ok, else `not_received` (partial). Other targets: `delivered` = ok, `delivery_failed` = failed, `no_report` = partial (networks may not return reports). Not sent = failed.
- Privacy: dialled numbers are kept only in local settings; results store `target_masked` (last two digits). Message text is matched in memory and never stored.

## 6a. Cell scan and estimated sites (issue #27)
- **Cell scan** aggregates stored `cell_observations` (serving and neighbour). Cell key: RAT + PLMN + cell ID; cells without identity (neighbours reporting only ARFCN + PCI) are keyed by RAT + ARFCN + PCI and take the identity of the single identified cell on the same channel when it is unambiguous. Mean level is the mean of dBm values.
- **Site** = eNB ID (LTE) or gNB ID (NR); other RATs: the cell. Positions come from all sessions, so they improve with every drive. Mock-location and no-fix samples are excluded; GOOD fixes are used when there are at least 3.
- **Timing-advance fit (preferred)**: LTE serving-cell TA index → range `(TA + 0.5) × 78.12 m` (3GPP TS 36.213: one step = 16 Ts). Least-squares (Gauss-Newton) fit of the site position to ≥ 3 distinct ranges spread over ≥ 150 m, started from 9 points; if a mirror solution > 200 m away fits about as well (straight road) the fit is rejected. Uncertainty = max(80 m, 2 × RMS residual + 39 m). Safeguards: ranges > 35 km are ignored, the solver step is damped to 1 km per iteration and stops on near-collinear geometry, and a fit with RMS residual > 400 m, outside the farthest range + 1 km, or > 50 km from the samples is rejected (fallback below).
- **Level centroid (fallback)**: level-weighted (linear power) centroid of the strongest quarter (≥ 3) of samples. It lies on the driven road, so uncertainty = max(200 m, 2 × weighted spread).
- **Sector azimuth**: weighted circular mean of bearings from the site to the cell's strongest samples, reported only if the mean resultant length ≥ 0.5 and most of those samples lie outside half the uncertainty radius.
- Estimated positions are labelled "estimated" everywhere (app, KML). They are not survey data and must not be used as such in regulatory findings.

## 7. References
ITU-T E.800, G.1010, G.1020, P.863, Y.1540 · 3GPP TS 36.214, 36.133, 38.215, 38.133, 23.203, 32.450 · ETSI EG 202 057 · RFC 3393, 3550, 7946 · GSMA network benchmarking guidance.
