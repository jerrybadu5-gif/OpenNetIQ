# ADR-002: Riverpod for state management

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Measurement streams (radio, GPS, throughput) need reactive, testable state with dependency injection.

## Decision
Use `flutter_riverpod` with code generation (`riverpod_generator`). Providers act as the DI container; repositories are injected via providers.

## Consequences
Compile-safe DI, easy overriding in tests. Team must follow provider naming conventions (`xxxRepositoryProvider`, `xxxControllerProvider`).
