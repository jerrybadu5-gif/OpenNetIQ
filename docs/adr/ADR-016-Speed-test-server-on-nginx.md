# ADR-016: Speed-test server on nginx; ndt7 fallback needs consent

- Status: Accepted
- Date: 2026-10-09
- Deciders: OpenNetIQ core team
- Amends: ADR-007

## Context
ADR-007 chose a self-hosted, LibreSpeed-compatible server as the reference target and M-Lab ndt7 as fallback. The reference server must reach >= 1 Gbit/s on modest hardware, be easy for a regulator to operate, and must not collect personal data. M-Lab publishes every ndt7 measurement, including the client IP address, as open data.

## Decision
- Implement the server as a hardened **nginx** container (non-root, read-only, pinned digest) serving LibreSpeed's endpoint paths: a pre-generated incompressible file for download (`sendfile`), body discard for upload, plus `getIP`, `ping` and `health`. Not the PHP LibreSpeed backend.
- No access logs by default.
- The **ndt7 fallback is deferred**: it may only be offered after explicit, logged user consent that the IP address and results are published by M-Lab (consent work in #24). Until then, a configured self-hosted server is required.

## Consequences
- Line-rate serving with little CPU; one container image for all regulator/operator deployments; existing LibreSpeed web clients also work against it.
- Without a configured server the app cannot run a speed test (it says so); field campaigns must deploy the server first.
- ndt7 remains on the roadmap behind consent.
