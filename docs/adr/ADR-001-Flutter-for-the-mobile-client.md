# ADR-001: Flutter for the mobile client

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
OpenNetIQ needs a cross-platform UI (Android first, iOS/Web later) with a single codebase and a strong open-source ecosystem.

## Decision
Use Flutter (stable channel) for all UI and orchestration in `apps/mobile`. Telecom/location measurement is delegated to native Kotlin (ADR-005).

## Consequences
One UI codebase for Android, iOS and Web portal (ADR-011). Requires platform channels for native APIs. Dart is not used for timing-critical measurement.
