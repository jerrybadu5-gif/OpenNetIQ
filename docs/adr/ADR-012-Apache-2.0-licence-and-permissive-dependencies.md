# ADR-012: Apache-2.0 licence and permissive dependencies

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Regulators, operators and universities must be able to reuse the code commercially.

## Decision
License the project under Apache-2.0. Dependencies must be Apache/MIT/BSD/ISC/MPL; GPL/AGPL only as separate processes (e.g., test servers) and never linked.

## Consequences
Broad adoption; a licence check runs in CI (Phase 2).
