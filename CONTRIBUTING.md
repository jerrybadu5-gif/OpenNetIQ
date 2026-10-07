# Contributing to OpenNetIQ

1. Pick an issue (start with `good first issue`) and comment to claim it.
2. Branch from `develop`: `feature/<short-slug>` (e.g. `feature/signal-monitor`), `fix/<slug>`, `docs/<slug>`.
3. Follow `CLAUDE.md` conventions (Clean Architecture, UUIDv7, UTC, snake_case DB/API).
4. Add tests (coverage >= 80 %) and update docs (README/ARCHITECTURE/API/TESTING sections of the feature).
5. Commit style: Conventional Commits (`feat(radio): add NR SS-SINR mapping`).
6. Open a PR to `develop`; complete the template; CI must be green; 1 approval required.
7. Methodology or schema changes require an ADR.

Releases: `develop` → `main` via release PR, tagged `vX.Y.Z` (SemVer).
