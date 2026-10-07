# ADR-006: AOSP LocationManager instead of Fused Location

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Fused Location Provider depends on proprietary Google Play Services, blocks F-Droid distribution and smooths positions (bad for drive tests).

## Decision
Use `LocationManager.GPS_PROVIDER` at 1 Hz; record accuracy, satellites and fix age. Network provider used only for a coarse initial fix.

## Consequences
Open-source compatible, raw GNSS positions. Slower first fix indoors; UI shows GNSS status.
