# ADR-007: Speed-test server strategy

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team

## Context
Throughput results depend on server location and capacity; regulators need a controlled reference.

## Decision
Primary: self-hosted OpenNetIQ test server (LibreSpeed-compatible HTTP endpoints, Docker, `infra/test-server`). Fallback: M-Lab ndt7 public servers. Multi-connection HTTP method v1.0 (4 streams, 10 s, 2 s ramp-up excluded).

## Consequences
Reproducible in-country measurements. Server operation becomes a deployment responsibility; results always record server ID and method version.
