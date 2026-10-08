# Measurement Methodology — v1.0.0

`methodology_version = 1.0.0` · Applies to Phase 1 (M1). Changes require an ADR (ADR-009).

## 1. Sampling
| Item | Value |
|---|---|
| Drive-test sampling interval | 1 s (default), 2 s, 5 s |
| Radio refresh | `TelephonyManager.requestCellInfoUpdate()` per tick; cell data older than 2 s flagged `STALE` |
| GNSS | `GPS_PROVIDER`, 1 Hz; fix age > 2 s or accuracy > 50 m → `gps_quality = POOR` |
| Clock | Device UTC; each sample stores `timestamp` (sample time) and `radio_timestamp` (CellInfo timestamp) |

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
6. Test invalid if: radio RAT changes mid-test (flagged, not dropped), < 1 MB transferred, or server error.

## 6. Latency (method `lat-1.0`)
- ICMP: 20 echo requests, 200 ms interval, 56-byte payload, 2 s timeout.
- TCP: 20 connects to server port 443, RTT = SYN→SYN/ACK as seen by connect().
- KPIs: `min, max, mean, median, p95` (nearest-rank), `jitter_ms = mean(|RTTᵢ − RTTᵢ₋₁|)` over successful consecutive probes (IPDV, RFC 3393), `packet_loss_pct = lost / sent × 100`.

## 7. References
ITU-T E.800, G.1010, G.1020, P.863, Y.1540 · 3GPP TS 36.214, 36.133, 38.215, 38.133, 23.203, 32.450 · ETSI EG 202 057 · RFC 3393, 3550, 7946 · GSMA network benchmarking guidance.
