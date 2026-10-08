# ADR-013: Typed platform channels instead of Pigeon (for now)

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team
- Amends: ADR-005 (Pigeon-generated APIs)

## Context
ADR-005 planned Pigeon-generated platform APIs. Pigeon adds a code-generation step whose output (Kotlin + Dart) must be regenerated and committed on every contract change, and whose generated names change between Pigeon majors. The measurement layer needs one method channel (permissions) and one event stream per collector, carrying flat records already defined by the data dictionary.

## Decision
Use hand-written `MethodChannel` / `EventChannel` with:
- payloads as maps using the exact `snake_case` column names of `docs/standards/DATA-DICTIONARY.md`;
- one documented contract per feature (`docs/features/<feature>/API.md`);
- strict mappers on both sides (Kotlin `toMap()`, Dart `ChannelReader`) that reject wrong types with `FormatException` instead of guessing;
- contract tests on both sides (Kotlin JUnit for `toMap()` keys, Dart tests through mocked channels).

Revisit Pigeon when the contract grows beyond ~5 methods/streams or iOS support starts.

## Consequences
- No generated code to maintain; mapping is fully unit-testable without a device.
- Type safety across the boundary comes from tests rather than the compiler; every new field needs a test on both sides.
- Issue #8 is delivered by this ADR and the signal-monitor contract.
