# OpenNetIQ Architecture

## 1. System context (target state, Phase 4)

```
┌───────────────────────── Android device ─────────────────────────┐
│ Flutter UI (Riverpod)                                            │
│   features/: signal_monitor · speed_test · latency · drive_test  │
│              sessions · export · settings · consent              │
│        │ Pigeon platform channels (typed)                        │
│ Kotlin measurement layer                                         │
│   RadioCollector · LocationCollector · SpeedTestEngine           │
│   LatencyEngine · DriveTestForegroundService                     │
│        │                                                         │
│ Drift / SQLite (WAL)  ──▶ CSV · GeoJSON · KML exports            │
│        │ sync queue (Phase 2)                                    │
└────────┼─────────────────────────────────────────────────────────┘
         │ HTTPS, gzip NDJSON batches, idempotent by measurement_id
         ▼
┌──────────── Backend (Docker Compose → Kubernetes) ───────────────┐
│ FastAPI API (/v1)  ── auth (Keycloak OIDC, Phase 4)              │
│   measurement · session · coverage · reporting · admin           │
│ Workers: aggregation (H3), exports (GDAL), reports               │
│ PostgreSQL 16 + PostGIS + h3-pg   Redis (cache/queue)            │
│ Martin vector tiles   DuckDB/Parquet analytics                   │
│ Prometheus + Grafana                                             │
└──────────────────────────────────────────────────────────────────┘
         ▲                                 ▲
 Flutter Web portal (Phase 2)      Test servers (HTTP multi-conn, UDP echo)
```

## 2. Mobile layering (Clean Architecture, DDD-lite)

```
apps/mobile/lib/
  core/            # errors, result type, uuid_v7, time (UTC), logging, theme
  platform/        # Pigeon-generated APIs + adapters
  data/            # Drift database, DAOs, DTO ↔ entity mappers, repositories impl
  domain/          # entities, value objects (Rsrp, Rsrq, NetworkType), repository interfaces, use cases
  features/<name>/ # presentation: screens, widgets, Riverpod controllers
apps/mobile/android/app/src/main/kotlin/org/opennetiq/
  measurement/radio/    RadioCollector, CellInfoMapper, NsaDetector
  measurement/location/ LocationCollector
  measurement/speed/    SpeedTestEngine (OkHttp), ThroughputSampler
  measurement/latency/  LatencyEngine (ICMP/TCP/DNS)
  measurement/service/  DriveTestService (foreground, ADR-014)
  bridge/               Pigeon host API implementations
```

Dependency rule: `features → domain ← data → platform`. Domain has no Flutter or plugin imports.

## 3. Data flow (drive test, Phase 1)
1. `DriveTestService` (foreground, type `location`) keeps the process and the application-owned Flutter engine alive (ADR-014); `RadioCollector` ticks every *n* ms → requests cell update; `LocationCollector` streams GNSS.
2. Kotlin emits snapshots on the `radio` and `location` event channels; `recordingPipelineProvider` (root container, no screen needed) joins each tick with the latest fix.
3. `RecordingController` → `SampleRepository` → Drift transaction (sample + cell observations + session counters). Gap analysis at Stop; orphaned sessions aborted at next start.
4. Optional scheduled tests run in Kotlin; results linked by `measurement_id` snapshot.
5. Export use cases stream rows from Drift to CSV/GeoJSON writers (no full in-memory load).

## 4. Key quality attributes
| Attribute | Approach |
|---|---|
| Accuracy | Native APIs, raw values, validity ranges, methodology versioning, field validation |
| Reliability | Foreground service, WAL, per-sample commits, gap detection |
| Privacy | No IMEI/IMSI/MSISDN, consent ledger, local-only Phase 1, k-anonymity for public data |
| Observability | Structured logs; backend `/health`, `/metrics` |
| Scalability | Partitioned samples, H3 pre-aggregation, vector tiles, stateless API |

See `docs/adr/` for decisions and `docs/ROADMAP.md` for phasing.
