# ADR-020: Test scripts reuse the test controllers

## Context
G-NetTrack Pro runs data/voice/SMS sequences during drives. OpenNetIQ needs
the same (#28) without duplicating measurement code or methodology.

## Decision
- A script is JSON (format 1) stored in `app_settings`; the same JSON is the
  exchange format for multi-phone benchmarking (#31).
- `ScriptRunner` orchestrates; each step is executed by the existing
  feature controller through `StepExecutor`, so every result is stored,
  versioned and linked to the open drive exactly as a manual test.
- Cycles with optional fixed interval; stop cancels the running step.

## Consequences
- New test types (#29, #30) only need a controller and an executor case.
- Script/run identity is not stored with results until schema v2 (#31).
