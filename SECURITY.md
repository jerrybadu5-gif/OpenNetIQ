# Security Policy

## Reporting a vulnerability
Do **not** open a public issue. Use GitHub *Security → Report a vulnerability* (private advisory). We acknowledge within 5 working days.

## Supported versions
Latest minor release of the current major version.

## Controls
CodeQL, Trivy (filesystem + container), Dependabot, GitHub secret scanning, signed release APKs, branch protection. Secrets only via GitHub Secrets / environment variables — never committed.
