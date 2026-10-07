# ADR-008: UUIDv7 identifiers and UTC ISO 8601 time

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Records are created offline on many devices and later merged.

## Decision
All primary keys are UUIDv7 generated on the device. All timestamps stored as UTC ISO 8601 (`2026-10-07T14:36:00.123Z`); epoch millis allowed internally in Kotlin only.

## Consequences
Collision-free offline IDs, time-ordered indexes, idempotent uploads.
