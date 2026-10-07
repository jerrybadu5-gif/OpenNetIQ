# OpenNetIQ

**Open-source mobile network experience measurement platform** — QoS/QoE testing, signal monitoring, drive testing, coverage mapping and operator benchmarking for regulators, operators, researchers and field engineers.

[![Mobile CI](../../actions/workflows/mobile.yml/badge.svg)](../../actions/workflows/mobile.yml)
[![Backend CI](../../actions/workflows/backend.yml/badge.svg)](../../actions/workflows/backend.yml)
[![CodeQL](../../actions/workflows/codeql.yml/badge.svg)](../../actions/workflows/codeql.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> Status: **Phase 0 – Foundation**. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Capabilities (by phase)
| Phase | Capability |
|---|---|
| 1 – MVP | Live signal (2G/3G/4G/5G NSA/SA), GPS, speed test, latency/jitter/loss, drive-test sessions (1/2/5 s), local storage, CSV & GeoJSON export |
| 2 | Backend + PostGIS, upload/sync, H3 coverage maps, drive-test replay, KML/GeoPackage |
| 3 | Web/video/voice QoE tests, QoE scoring, analytics dashboards |
| 4 | Crowdsourcing, operator rankings, regulator QoS compliance reports |
| 5 | Anomaly detection, coverage prediction |

## Repository layout
```
apps/mobile          Flutter app + Kotlin measurement layer
backend/api          FastAPI service (Phase 2)
backend/analytics    DuckDB analytics & KPI library (Phase 3)
backend/workers      Aggregation/export workers (Phase 2)
database/mobile      Local SQLite/Drift schema
database/postgis     Server PostGIS schema
docs/                Roadmap, architecture, ADRs, standards
infra/               Docker Compose, test servers, k8s (later)
scripts/github       Repo bootstrap (labels, milestones, backlog issues)
standards/           Reference notes on ITU/3GPP/ETSI standards
tests/               Cross-component & field-validation tests
```

## Standards alignment
ITU-T E.800, G.1010, G.1020, P.863 · 3GPP TS 36.214, 36.133, 38.215, 38.133, 23.203, 32.450 · ETSI EG 202 057 · GSMA benchmarking guidance. Methodology: [docs/standards/MEASUREMENT-METHODOLOGY.md](docs/standards/MEASUREMENT-METHODOLOGY.md).

## Getting started
```bash
git clone https://github.com/<owner>/opennetiq.git && cd opennetiq
git checkout develop
# One-time GitHub setup (labels, milestones, backlog issues) — requires gh CLI:
./scripts/github/bootstrap.sh <owner>/opennetiq
```

## Contributing
GitHub Flow: `feature/*` → `develop` → `main`. Read [CONTRIBUTING.md](CONTRIBUTING.md).

## License
[Apache 2.0](LICENSE)
