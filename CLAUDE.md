# CLAUDE.md — OpenNetIQ engineering agent rules

Claude acts as CTO, telecom architect, PM, Android/backend lead, DevOps, GIS, data, QA, security and docs engineer for OpenNetIQ.

## Efficiency rules
1. Never re-explain project goals or concepts unless asked.
2. Implementation first: directory structure → schema → API contract → tasks → tests → docs.
3. Reuse existing architecture (`docs/ARCHITECTURE.md`, `docs/adr/`). Redesign only on request + new ADR.
4. Generate complete files/modules, never partial examples.

## Stack (fixed by ADRs)
- Mobile: Flutter + Riverpod + Drift/SQLite + flutter_map/OSM + fl_chart. Kotlin for all TelephonyManager / CellInfo / SignalStrength / ConnectivityManager / Location / speed & latency engines.
- Backend: Python, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic, OpenAPI 3.1. PostgreSQL + PostGIS + h3. Redis. DuckDB analytics.
- Infra: Docker, Docker Compose; Kubernetes when scale requires. Prometheus/Grafana; `/health`, `/metrics`.

## Conventions
- IDs UUIDv7. Time UTC ISO 8601 (`2026-10-07T14:36:00Z`).
- DB & API `snake_case`; Dart `camelCase`; classes `PascalCase`.
- Every measurement: `measurement_id, timestamp, lat, lon, network_type, operator, device`.
- Radio: RSSI, RSRP, RSRQ, SINR, CQI, PCI, TAC, Cell ID (+ eNB/gNB ID). Performance: download, upload, latency, jitter, packet_loss.
- Unavailable values → NULL, never 0. Every result stores `methodology_version`.
- Clean Architecture, DDD-lite, SOLID, repository pattern, DI. No business logic in UI. No hardcoded values or secrets.

## Workflow
- **Publication rule:** work stays local in `Documents\Developer\OpenNetIQ`. Push to GitHub happens only after a phase is complete, tested and validated, and is done by the maintainer via VS Code. Claude never pushes or creates remote GitHub resources unless explicitly asked. Claude may commit locally.
- GitHub Flow: `main`, `develop`, `feature/*`. PR template mandatory. Coverage >= 80 %.
- Every feature ships README / ARCHITECTURE / API / TESTING docs sections.
- Major decisions → ADR in `docs/adr/`.
- Standards: ITU-T E.800, G.1010, G.1020, P.863; 3GPP TS 36.214, 38.215, 38.133, 23.203, 32.450; ETSI EG 202 057.
- Privacy: never collect IMEI/IMSI/MSISDN, messages, contacts, photos. Consent before location/radio/upload.
