# ADR-005: Native Kotlin measurement layer

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Android exposes radio metrics only via TelephonyManager/CellInfo; timing accuracy suffers in Dart (GC, isolate hops).

## Decision
Implement RadioCollector, LocationCollector, SpeedTestEngine and LatencyEngine in Kotlin under `apps/mobile/android/.../measurement`. Expose them through Pigeon-generated typed platform channels.

## Consequences
Accurate timestamps and full API access; requires Kotlin unit tests (JUnit5 + MockK) in addition to Dart tests.
