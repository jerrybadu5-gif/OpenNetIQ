# NICTA Telecommunications QoS Rule 2022 — OpenNetIQ traceability

Source: *Telecommunications Quality of Service (QoS) Rule 2022*, NICTA
(National ICT Act 2009). It applies to fixed and mobile applications
licensees. NICTA verifies licensee reports with its own audits and tests
(s.12), and OpenNetIQ is the tool NICTA uses for that verification. This
file maps each Rule parameter to what OpenNetIQ measures. It is the
acceptance reference for field validation (#25) and release #26.

Status: **Met** = measured as the Rule describes · **Partial** = measured,
with a deviation that is documented · **Gap** = not yet measured (a backlog
item is proposed).

## Schedule 1 — Mobile telephony (s.5)

| Ref | Parameter / guideline | Requirement | OpenNetIQ | Status |
|---|---|---|---|---|
| S1 | Telephony service non-accessibility (call failure rate) | ≤ 2 %; intra- and inter-network | `voice_sms_tests` (kind `call`): failed attempts = outcome `not_placed`, `rejected`, `no_answer`, `setup_timeout` ÷ attempts. Results with outcome `unknown`/`ended_early` (no call log) are reported separately and excluded | Met |
| S1 | Telephony cut-off call ratio (call drop rate) | ≤ 2 % | `dropped` ÷ (`completed` + `dropped`) | Met |
| G1–G2 | Phones with a QoS measurement system; ETSI/3GPP compliant | — | Android app. KPI definitions follow ETSI TS 102 250-2. Setup time comes from the call log (1 s resolution), not from layer-3 messages (ADR-022) | Partial |
| G3 | Measure only where the licensee's coverage prediction shows coverage | — | Campaign planning (coverage-prediction overlay in the portal, Phase 2) | Gap |
| G4 | Calls go to a PSTN number provided by the licensee | — | Call lines are configured per campaign (`Name \| number`) | Met |
| G5–G6 | Mobile-originated calls; drive or static test | — | `placeCall`; session type drive / static | Met |
| G7 | WGS-84 positioning | — | GNSS fixes in WGS 84 | Met |
| G8 | 2G, 3G, VoLTE, VoNR | — | `voice_rat` per call (GSM / UMTS / VoLTE / VoNR, `A>B` on a change) | Met |
| G9 | Call window: setup 20 s, holding 120 s, interval 30 s, total 170 s | — | Defaults: setup timeout 20 s (a later setup = `setup_timeout`, counted as a failure), release 140 s after dialling (so a call set up in time is held ≥ 120 s), 30 s interval between calls; preset script "NICTA voice (Schedule 1)" repeats every 170 s | Met |
| G11 | ≥ 100 call samples per region per measurement period | — | `onq-validate report` sample checks per region (M16) | Met |

## Schedule 2 — Mobile broadband (s.6)

| Ref | Parameter / guideline | Requirement | OpenNetIQ | Status |
|---|---|---|---|---|
| S2 | FTP download mean data rate | ≥ 2.5 Mbps in ≥ 90 % of samples (from 2024); ≥ 10 samples per location | FTP file transfer (`qoe_tests` kind `file`, protocol `ftp`): bytes × 8 / transfer time. Sample count per location checked in the M16 report | Met |
| S2 | FTP upload mean data rate | ≥ 0.5 Mbps in ≥ 90 %; ≥ 10 per location | FTP upload (default 10 MB) | Met |
| S2 | Ping round-trip time | ≤ 250 ms in ≥ 80 %; ≥ 100 samples per location | ICMP ping, 56-byte payload (64-byte packet, within 32–128), 20 probes per test | Partial (5 tests per location needed) |
| S2 | HTTP web browsing | Page download ≤ 10 s in ≥ 80 %; 5 pages chosen by NICTA; ≥ 10 per location | Web test: full page load time (W3C Navigation Timing) for the 5 configured pages | Met |
| S2 | Minimum received signal level | LTE RSRP ≥ −110 dBm, WCDMA RSCP ≥ −100 dBm, in ≥ 80 %; taken from the FTP download samples | `serving_level_dbm` / `serving_rat`: mean serving level during each FTP download | Met |
| G4 | Test server and verifier at the internet exchange in Port Moresby | — | Speed-test and FTP servers (`infra/test-server`, ADR-016/023); deployment at PNG IX pending | Partial (deployment) |
| G5 | Static or walk test | — | Session type static / walk | Met |
| G8 | Throughput uses FTP | — | FTP client (Commons Net) + FTP server (pyftpdlib), ADR-023 | Met |
| G9 | File size: 100 MB for LTE download, 50 MB for 3G | — | Download size by network type at the run start (100 MB LTE/5G, 50 MB 3G) | Met |
| G10 | Ping packet 32–128 bytes | — | 64 bytes | Met |
| G11 | 5 web pages chosen by NICTA | — | 5 defaults; editable list | Met |
| G13 | ≥ 30 locations per region | — | Campaign tags + report sample checks (M15, M16) | Met |

## Schedules 3–5 — Fixed telephony, fixed broadband, user-related

These are measured from operator network statistics or a probe on the
customer's router, not a mobile phone, so they are **out of scope for the
app**. A future Linux probe could cover Schedule 4 (FTP/ping against the same
test server). Schedule 5 is operator reporting.

## Reporting (s.10–11) and enforcement (s.13)

| Ref | Requirement | OpenNetIQ | Status |
|---|---|---|---|
| 10(1) | Results within 30 days of each half-year period (1 Jan – 30 Jun, 1 Jul – 31 Dec) | Exports + `report --period 2026H1/H2` | Met |
| 10(2) | Report by location; separate urban / semi-urban / rural | Campaign tags on every session (region, area class, location), exported in every record (M15) | Met |
| 10(3) | Appendix A/B templates; % to one decimal place; details as a digital map or Excel | `onq-validate report --rule nicta-qos-2022`: Appendix A/B per region and area to one decimal, Excel/CSV; maps from GeoJSON/KML exports | Met |
| 10(4) | Measurement log files on request | Raw per-sample and per-test exports with `methodology_version` | Met |
| 10(5) | No re-measurement at the same location within 2 years (except to reassess) | Report could warn | Gap |
| 13(7) | No manipulation (network changes, prioritised SIMs, device changes) | Device model and Android version, operator, PLMN, RAT and cell identity in every record. Export integrity hashes proposed | Partial |

## Backlog (decided 2026-10-25: items 1–3 in v0.1.0, spec v3 M14–M16)

1. ✅ **FTP throughput test** (Schedule 2 G8), done (ADR-023). Kotlin FTP client (Apache Commons
   Net, Apache-2.0) with passive RETR/STOR, file size by RAT (100 MB LTE,
   50 MB 3G), plus vsftpd in `infra/test-server`.
2. ✅ **Campaign metadata per session**, done (ADR-023). Region (PNG: Southern, Highlands,
   Momase, Islands, or province), area class (urban / semi-urban / rural)
   and location name. Can be folded into schema v3 while it is unreleased.
3. ✅ **Compliance report**, done (`onq-validate report`). Appendix A and B per region and area class, with
   threshold pass rates to one decimal place and sample-count checks
   (100 calls per region, 10 samples per location, 100 pings per location,
   30 locations per region). Generated from exports (`onq-validate report
   --rule nicta-qos-2022`, Excel/CSV).
4. **Configurable ping count** (100 probes per test).
