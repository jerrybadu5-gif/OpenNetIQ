# ADR-004: Drift (SQLite) for local storage

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Phase 1 is offline-first; sessions must survive crashes and app kills.

## Decision
Use Drift over SQLite in WAL mode. Schema mirrors server model (`database/mobile/schema_v1.sql`) to make sync a straight mapping.

## Consequences
Type-safe queries and migrations in Dart. Large sessions (>1 M rows) require paging and indexed exports.
