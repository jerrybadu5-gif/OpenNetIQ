# ADR-010: Monorepo with GitHub Flow

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Mobile, backend, database and docs change together around a shared data model.

## Decision
Single repository `opennetiq` with `apps/`, `backend/`, `database/`, `docs/`, `infra/`. Branches `main`, `develop`, `feature/*`; path-filtered CI workflows.

## Consequences
Atomic cross-component changes; CI must use path filters to stay fast.
