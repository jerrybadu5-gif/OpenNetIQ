# OpenNetIQ — Execution Roadmap

Status: **Approved baseline v1.0** · Date: 2026-10-08 · Owner: Jerry Badu

This is the phased execution plan for OpenNetIQ. Each phase maps 1:1 to a GitHub milestone and ends with measurable exit criteria. Work is tracked locally against `scripts/github/backlog.json` and pushed to GitHub only at phase completion (see Publication Policy).

---

## 0. Phase Overview

| Phase | Milestone | Theme | Duration* | Key Output |
|---|---|---|---|---|
| 0 | `M0 – Foundation` | Repo, CI/CD, ADRs, standards | 1–2 wks | Buildable empty app + green pipelines |
| 1 | `M1 – MVP` | Local-first Android measurement app | 10–12 wks | Signal monitor, speed test, latency, GPS, drive-test sessions, CSV/GeoJSON export |
| 2 | `M2 – Coverage & Drive Test` | Backend + PostGIS + maps | 10 wks | Upload/sync API, coverage maps (H3), drive-test replay, KML |
| 3 | `M3 – QoE & Analytics` | Service experience + analytics | 12 wks | Web/video/voice tests, QoE scoring, DuckDB analytics, dashboards |
| 4 | `M4 – Crowdsourcing & Benchmarking` | Scale + regulator reporting | 12 wks | Accounts, consent-based crowdsourcing, operator rankings, regulator reports |
| 5 | `M5 – Intelligence` | AI/ML | Ongoing | Anomaly detection, coverage prediction, insights |

\*Durations assume 1–2 developers working with Claude. Phases are sequential; within a phase, epics run in parallel where dependencies allow.

### Guiding constraints (apply to every phase)
- **Android-first, offline-first.** Nothing in Phase 1 requires a network service except the speed/latency test target.
- **Native radio metrics.** All TelephonyManager / CellInfo / Location code is Kotlin; Dart only orchestrates and renders (CLAUDE.md rule).
- **Raw first, derived later.** Store raw API values plus unit/validity; KPIs are computed from raw data so methodology can change without re-collecting.
- **Every record:** `measurement_id` (UUIDv7), `timestamp` (UTC ISO 8601), `lat`, `lon`, `network_type`, `operator`, `device`.
- **Unavailable ≠ zero.** Android returns `CellInfo.UNAVAILABLE` (`Integer.MAX_VALUE`) for missing values → stored as `NULL`, never `0`.
- **Methodology is versioned.** Every test result carries `methodology_version` so regulator reports remain reproducible.

---

## Phase 0 — Foundation (M0)

**Goal:** a repository anyone can clone, build and contribute to, with quality gates enforced from day one.

| # | Epic | Deliverables |
|---|---|---|
| 0.1 | Repository | Monorepo layout, Apache-2.0 LICENSE, README, CLAUDE.md, CONTRIBUTING, SECURITY, PRIVACY, CODE_OF_CONDUCT |
| 0.2 | GitHub governance | Branches `main` / `develop` / `feature/*`, branch protection, labels, milestones M0–M5, issue & PR templates, CODEOWNERS |
| 0.3 | CI/CD | `mobile.yml` (format, analyze, test, build APK), `backend.yml` (ruff, mypy, pytest, coverage, docker build), CodeQL, Trivy, Dependabot |
| 0.4 | Architecture decisions | ADR-001 … ADR-012 (see `docs/adr/`) |
| 0.5 | Measurement standard | `docs/standards/MEASUREMENT-METHODOLOGY.md` v1.0 and `docs/standards/DATA-DICTIONARY.md` |
| 0.6 | Flutter skeleton | `apps/mobile` created with Riverpod, Drift, go_router, platform-channel stub, flavors `dev`/`prod` |

**Exit criteria**
- [ ] `flutter build apk --flavor dev` passes in CI
- [ ] All workflows green on `develop`
- [ ] Branch protection on `main` and `develop` (PR + status checks required; 1 approval once a second maintainer joins)
- [ ] ADR-001 … ADR-012 merged

---

## Phase 1 — MVP: Local-First Android App (M1)

**Goal:** a field engineer can drive a route, capture radio + GPS + performance data at 1 s resolution, and export it for QGIS/Excel — fully offline except for the test server.

**Platform:** `minSdk 29` (Android 10), `targetSdk 35`. Rationale: API 29 provides `requestCellInfoUpdate()`, `CellSignalStrengthNr`, `CellSignalStrengthLte.getRssi()`; API 30+ adds `TelephonyDisplayInfo` for 5G NSA detection (graceful degradation on 29).

### Epics

#### 1.1 Native Radio Engine (Kotlin) — `telecom`, `mobile`
- `RadioCollector` using `TelephonyCallback` (API 31+) with `PhoneStateListener` fallback (29–30).
- Active refresh via `TelephonyManager.requestCellInfoUpdate()` each sampling tick (bypasses stale cached `getAllCellInfo()`).
- Per-RAT mapping:

| RAT | Identity | Signal |
|---|---|---|
| GSM | MCC, MNC, LAC, CID, ARFCN, BSIC | RSSI, BER, TA |
| WCDMA | MCC, MNC, LAC, CID, PSC, UARFCN | RSCP, Ec/No, RSSI |
| LTE | MCC, MNC, TAC, ECI → **eNB ID = ECI >> 8**, **Cell = ECI & 0xFF**, PCI, EARFCN, Band, BW | RSRP, RSRQ, RSSNR (SINR), RSSI, CQI, TA |
| NR | MCC, MNC, TAC, NCI → gNB ID (configurable gNB-ID length 22–32 bits, default 24), PCI, NR-ARFCN, Band | SS-RSRP, SS-RSRQ, SS-SINR, CSI-RSRP, CSI-RSRQ, CSI-SINR |

- **5G NSA detection:** `TelephonyDisplayInfo.overrideNetworkType` (`NR_NSA`, `NR_ADVANCED`) + `ServiceState` NR state; record `network_type = NR_NSA` with LTE anchor as serving cell and NR leg from `CellSignalStrengthNr` when reported.
- Serving + neighbour cells stored (`is_serving` flag).
- Validity ranges per 3GPP TS 36.133 / TS 38.133 reporting ranges (e.g., RSRP −156…−31 dBm, RSRQ −34…+2.5 dB); out-of-range → `NULL` + `quality_flag`.
- Platform channel: `EventChannel` stream `opennetiq/radio` + `MethodChannel` `opennetiq/control`, Pigeon-generated typed interface.

#### 1.2 Location Engine (Kotlin) — `gis`, `mobile`
- `LocationManager.GPS_PROVIDER` (AOSP, no Google Play Services dependency → F-Droid compatible; ADR-006).
- Captures lat, lon, altitude, speed, bearing, horizontal accuracy, vertical accuracy, satellites used, provider.
- GNSS fix age guard: samples with fix age > 2 s or accuracy > 50 m flagged `gps_quality = POOR`; fixes older than 30 s dropped (`NONE`).
- Mock-location detection (`Location.isMock`): samples flagged `MOCK_LOCATION` and excluded from regulatory statistics.
- Status: implemented in issue #14 (`docs/features/location/`).

#### 1.3 Drive-Test Session Engine — `mobile`
- Foreground service (`foregroundServiceType="location|dataSync"`) with persistent notification; survives screen-off.
- Sampling interval selectable: **1 s / 2 s / 5 s**.
- Session lifecycle: `created → recording → paused → completed | aborted`; crash-safe (WAL mode, every sample committed).
- Session metadata: name, route/area, operator under test, vehicle/walk, notes, device, app version, methodology version.
- Optional scheduled test script per session: e.g., *every 60 s: latency (20 pings) + DL (10 s) + UL (10 s)*.

#### 1.4 Speed Test Engine (Kotlin, OkHttp) — `telecom`
- Kotlin implementation for timing accuracy (no Dart isolate/GC jitter in the hot path).
- Server targets (ADR-007):
  1. **Self-hosted OpenNetIQ test server** (LibreSpeed-compatible HTTP endpoints, Docker image in `infra/test-server`) — regulator-controlled, the reference target.
  2. **M-Lab ndt7** (public, Apache-2.0 client protocol) — fallback when no self-hosted server is configured.
- Method v1.0: multi-connection HTTP (default 4 parallel TCP streams), 10 s per direction, 2 s ramp-up excluded, 100 ms throughput sampling. Reports mean, median, P10, P90, peak (burst) and bytes transferred. Also records TCP connect time and DNS resolution time.
- Radio snapshot taken at start, mid and end of each test and linked to the result.

#### 1.5 Latency Engine — `telecom`
- ICMP via `/system/bin/ping` (no root required), TCP connect RTT, HTTP RTT, DNS lookup time.
- Default: 20 probes, 200 ms interval. KPIs: min, max, mean, median, P95, **jitter = mean absolute difference of consecutive RTTs (IPDV, RFC 3393 / ITU-T Y.1540)**, packet loss % (ICMP).

#### 1.6 Local Storage (Drift / SQLite) — `mobile`
- Schema: `database/mobile/schema_v1.sql` (sessions, samples, cell_observations, speed_tests, latency_tests, devices, app_settings).
- UUIDv7 keys, UTC ISO 8601 timestamps, `schema_version`, `created_at`, `updated_at`.
- Retention setting + manual delete per session (privacy).

#### 1.7 UI (Flutter) — `mobile`
- Screens: Live Signal Dashboard (serving + neighbours, RAT, band, gauges), Speed Test, Latency, Drive Test (live map with RSRP-coloured track on flutter_map / OSM), Sessions list & detail, Export, Settings, Consent/Onboarding.
- RSRP colour scale per `docs/standards/MEASUREMENT-METHODOLOGY.md` (≥ −80 excellent … < −110 no/poor service).
- Charts with fl_chart (RSRP/SINR time series, throughput curve).

#### 1.8 Export — `gis`
- **CSV** (one row per sample, flat, documented column dictionary) and **GeoJSON** (RFC 7946, `Point` per sample + `LineString` per session).
- Share via Android share sheet / Storage Access Framework. File naming: `opennetiq_<session-name>_<UTC-start>.csv`.

#### 1.9 Privacy & Permissions — `security`
- Runtime consent screen before any location/radio collection; permissions: `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` (drive test only), `READ_PHONE_STATE`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE_LOCATION`.
- Never collect IMEI, IMSI, phone number, MSISDN, contacts, messages. Device identified by random install UUID.

#### 1.10 QA & Field Validation — `telecom`
- Unit tests: mappers (ECI→eNB, NCI→gNB), validity filters, KPI math (jitter, percentiles), CSV/GeoJSON writers. Coverage ≥ 80 %.
- Instrumented tests on ≥ 3 chipsets (Qualcomm, MediaTek, Samsung Exynos).
- **Field validation:** 3 drive routes in Port Moresby (urban, suburban, highway) against a reference (second device running a reference app such as Network Cell Info / G-NetTrack, or a commercial tool where available).

**Exit criteria (M1 release `v0.1.0`)**
- [ ] RSRP/RSRQ agree with reference within **±2 dB** median absolute difference on the same device model
- [ ] DL/UL throughput within **±10 %** of reference test on the same server, same location (n ≥ 30)
- [ ] 1 s sampling sustained ≥ 2 h with screen off, ≤ 1 % missing samples
- [ ] Battery drain ≤ 15 %/h during passive drive-test logging
- [ ] CSV and GeoJSON open cleanly in Excel and QGIS
- [ ] Zero crash-free-session regressions; ≥ 99 % crash-free sessions in beta
- [ ] Signed release APK published on GitHub Releases

---

## Phase 2 — Coverage Maps, Drive Testing & Backend (M2)

**Goal:** sessions leave the phone; coverage becomes a map a regulator can publish.

| # | Epic | Deliverables |
|---|---|---|
| 2.1 | Backend API | FastAPI + Pydantic v2 + SQLAlchemy 2 + Alembic; OpenAPI 3.1; `/health`, `/metrics` (Prometheus); API-key auth for field teams (JWT/OAuth2 in Phase 4) |
| 2.2 | PostGIS data model | `database/postgis/001_init.sql` → Alembic; `geography(Point,4326)`; partition `samples` by month; GIST + BRIN indexes |
| 2.3 | Upload & sync | Idempotent batch upload (`measurement_id` as idempotency key), gzip NDJSON, resumable; mobile sync queue with exponential backoff |
| 2.4 | Coverage aggregation | **H3 hexagon binning** (res 8 national, res 9 urban) per operator × RAT; metrics: median RSRP, P10 RSRP, sample count, % samples ≥ −105 dBm |
| 2.5 | Map serving | Martin vector tiles from PostGIS; MapLibre-compatible styles |
| 2.6 | Web portal v1 | Flutter Web (shared domain models with mobile, ADR-011): session list, drive-test replay, coverage layer toggle by operator/RAT/metric |
| 2.7 | Exports | KML, GeoPackage, Shapefile (via GDAL in worker), per-session PDF summary |
| 2.8 | Mobile maps | Offline map tiles for field use; coverage overlay on device |
| 2.9 | Infra | Docker Compose stack (api, postgis, redis, martin, prometheus, grafana); Trivy-scanned images on GHCR |

**Exit criteria (`v0.2.0`)**: 10 k samples/s ingest on a single 4 vCPU node; coverage map for a full test campaign renders < 2 s; zero duplicate samples after re-upload; API test coverage ≥ 80 %.

---

## Phase 3 — QoE, Service Testing & Analytics (M3)

| # | Epic | Deliverables | Standards |
|---|---|---|---|
| 3.1 | Web browsing test | DNS, TCP, TLS, TTFB, DOM loaded, full load for configurable URL list (WebView-instrumented) | ETSI TR 102 678 / EG 202 057, ITU-T G.1030 |
| 3.2 | Video streaming test | ExoPlayer/Media3 DASH test stream: start-up delay, stall count/ratio, mean bitrate, resolution switches, failures | ITU-T P.1203 (model), G.1010 |
| 3.3 | Voice testing (field-test build) | Default-dialer role (`InCallService`) for exact call states: call setup success rate, call setup time, dropped-call rate, failure cause, RAT used (CS / VoLTE / VoNR); MO calls to an auto-answer responder (second OpenNetIQ device or IVR test number); MOS estimate via E-model (G.107) — POLQA/P.863 only with licensed tools (Android blocks call-audio capture) | ETSI TS 102 250-2, ITU-T E.804, G.107, P.863, E.800 |
| 3.3a | SMS testing (field-test build) | `SmsManager` with sent/delivery reports to a test number; SMS send success ratio, end-to-end delivery time, completion failure ratio; receiver mode on a second device | ETSI TS 102 250-2, ITU-T E.804 |
| 3.3b | Field-test build flavor | `field` flavor holding dialer/SMS permissions, sideloaded or F-Droid only (Google Play restricts these permissions to default dialer/SMS apps); test SIMs only, never reads user calls/messages | Privacy-by-design |
| 3.4 | Packet loss/jitter (UDP) | UDP echo server in `infra/test-server`; loss, jitter, reordering | RFC 3550, Y.1540 |
| 3.5 | QoE scoring | Composite per-session QoE index (documented weights, versioned) | G.1010, G.1020 |
| 3.6 | Analytics | DuckDB over Parquet exports for campaign analytics; KPI library (`backend/analytics`) | E.800, TS 32.450 |
| 3.7 | Dashboards | Grafana (ops) + portal analytics: KPI trends, CDFs, RAT share, band usage | — |

**Exit criteria (`v0.3.0`)**: each service test has a published methodology document and reproducibility test; QoE index validated against ≥ 100 labelled sessions.

---

## Phase 4 — Crowdsourcing, Benchmarking & Regulator Reporting (M4)

| # | Epic | Deliverables |
|---|---|---|
| 4.1 | Identity | OAuth2/OIDC (Keycloak), JWT, roles: `public`, `field_engineer`, `operator`, `regulator_analyst`, `admin`; multi-tenant (`organisation_id`) |
| 4.2 | Crowdsourcing | Opt-in background passive sampling (battery-aware), consent ledger, upload only on Wi-Fi/charging options |
| 4.3 | Privacy engineering | Location fuzzing for public data, k-anonymity (k ≥ 5) on published hex bins, retention policies, data deletion & export requests (DSAR) |
| 4.4 | Data quality | Outlier & spoofing detection (mock-location flag, impossible speed), device-model calibration offsets |
| 4.5 | Operator benchmarking | Statistically controlled comparisons: same area/time windows, confidence intervals, minimum sample thresholds |
| 4.6 | Regulator reports | QoS compliance reports against licence KPIs (configurable thresholds), universal-service area monitoring, quarterly benchmarking report generator (PDF/DOCX) |
| 4.7 | Public portal | Operator rankings, coverage checker by address/area, open data downloads (CC-BY 4.0) |
| 4.8 | Scale | Kubernetes manifests/Helm, read replicas, object storage for raw files |

**Exit criteria (`v1.0.0`)**: national benchmarking report reproducible from raw data with one command; privacy review passed; load test 1 M samples/day.

---

## Phase 5 — Network Intelligence (M5)

- Anomaly detection on KPI time series (per cell / H3 bin): seasonal baselines, alerting.
- Coverage prediction: interpolation (kriging) then ML models with terrain/clutter (open DEM, OSM buildings).
- Complaint correlation: link consumer complaints to measured coverage/QoS.
- Automated insights: natural-language campaign summaries.
- Apache Spark only if DuckDB/Postgres limits are reached (measure first).

---

## Cross-cutting Workstreams

| Workstream | Ongoing activities |
|---|---|
| Measurement integrity | Methodology versioning, calibration log, field validation each release |
| Security | CodeQL, Trivy, Dependabot, secret scanning, threat model per phase, signed releases |
| Documentation | Every feature ships README / ARCHITECTURE / API / TESTING sections |
| Community | Contributor guide, good-first-issues, release notes, public roadmap board |
| Releases | SemVer; `v0.x` per phase; GitHub Releases with APK + checksums; F-Droid submission after M1 |

---

## Publication Policy (GitHub)

- Development happens **locally** in `Documents\Developer\OpenNetIQ` (git commits locally on `develop` / `feature/*`).
- Code is pushed to GitHub **only when a phase is complete**: all epics done, exit criteria met, tests passing, field-tested.
- The push is done **by the maintainer from VS Code** (Source Control → Push). Claude never pushes, creates remote repos, or opens remote PRs/issues unless explicitly asked.
- Phase gate checklist before push:
  1. All phase exit criteria ticked in this document
  2. `flutter analyze`, `flutter test --coverage` (≥ 80 %), Kotlin unit tests green locally
  3. Field validation report committed (`docs/validation/`)
  4. CHANGELOG entry + version tag (`v0.N.0`) created locally
  5. Merge `develop` → `main` locally, then push `main`, `develop` and tags from VS Code
- First push (end of Phase 0 or Phase 1): run `scripts/github/bootstrap.sh <owner>/opennetiq` once afterwards to create labels, milestones and backlog issues.

---

## Branching & Release Flow

```
feature/<epic-slug>  ──PR──▶  develop  ──release PR──▶  main  ──tag──▶  vX.Y.Z (GitHub Release)
```
- Branch names: `feature/signal-monitor`, `feature/speed-test`, `feature/latency`, `feature/gps`, `feature/drive-test`, `feature/local-storage`, `feature/export`, `feature/coverage-map` …
- PRs require: green CI, review (1 approval once ≥ 2 maintainers), PR template complete, linked issue.

---

## Phase 1 Sprint Plan (2-week sprints)

| Sprint | Focus | Issues |
|---|---|---|
| S0 | Foundation (M0) | Repo, CI, ADRs, Flutter skeleton, Pigeon channel |
| S1 | Radio engine LTE/NR + live signal screen | 1.1, 1.7 (signal) |
| S2 | GSM/WCDMA, neighbours, NSA detection, location engine | 1.1, 1.2 |
| S3 | Drift schema, drive-test service, session UI, live map | 1.3, 1.6, 1.7 |
| S4 | Speed test + latency engines, test server container | 1.4, 1.5 |
| S5 | Export, consent, settings, tests to 80 % | 1.8, 1.9, 1.10 |
| S6 | Field validation, fixes, beta, `v0.1.0` release | 1.10 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OEM-specific CellInfo gaps (e.g., missing SINR/CQI, NR not reported in NSA) | Incomplete radio data | Store NULL + `quality_flag`; publish device capability matrix; test on 3 chipsets |
| Android throttling of `requestCellInfoUpdate` | Lower effective sample rate | Record actual `radio_timestamp` vs sample time; flag stale cells (age > 2 s) |
| Background limits / battery optimisation kill logging | Data gaps | Foreground service + battery-optimisation exemption prompt; gap detection in session QA |
| Speed-test server capacity/location bias | Inaccurate throughput | Self-hosted in-country server; record server ID/location; ≥ 1 Gbps server uplink |
| Privacy/regulatory exposure (Phase 4) | Legal / trust | Privacy-by-design, DPIA before crowdsourcing launch, k-anonymity |
| Scope creep vs. commercial tools | Delays | Strict milestone exit criteria; Phase 1 local-only |
