# ADR-003: PostgreSQL + PostGIS for server storage

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Coverage mapping and drive-test analytics are spatial; regulators need reproducible SQL-accessible data.

## Decision
Use PostgreSQL 16 + PostGIS 3.4 from Phase 2. `geography(Point,4326)` for samples, H3 for aggregation, monthly partitioning of samples.

## Consequences
Mature open-source GIS stack compatible with QGIS. Requires partition management and index tuning at scale.
