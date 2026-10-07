# ADR-009: Measurement methodology versioning

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
KPI definitions will evolve; regulator reports must remain reproducible.

## Decision
Store raw values and a `methodology_version` (SemVer) on every test result. Methodology lives in `docs/standards/MEASUREMENT-METHODOLOGY.md`; changes require an ADR.

## Consequences
Historical data can be recomputed; adds a field to every result table.
