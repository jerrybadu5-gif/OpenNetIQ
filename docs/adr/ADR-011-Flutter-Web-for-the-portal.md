# ADR-011: Flutter Web for the portal

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Phase 2 needs a web portal sharing domain models with mobile.

## Decision
Build the portal with Flutter Web + flutter_map; heavy spatial aggregation is server-side (H3 + Martin vector tiles) so the client renders aggregates only.

## Consequences
One language for clients. Revisit (MapLibre GL JS) if rendering >50 k features client-side becomes necessary.
