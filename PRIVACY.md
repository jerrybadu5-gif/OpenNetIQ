# Privacy by Design

| Principle | Implementation |
|---|---|
| Data minimisation | No IMEI, IMSI, MSISDN, phone number, contacts, messages, photos or user content. Device = random install UUID. |
| Consent | Explicit, versioned consent (logged in `consent_log`) before location, radio, background-location and upload. |
| Local-first | Phase 1 stores everything on the device only. Nothing leaves the device unless the user exports or (Phase 2+) uploads. |
| Control | Delete any session or all data in-app; export your data at any time. |
| Publication (Phase 4) | Public maps use H3 aggregates with k-anonymity (k >= 5); location fuzzing for crowdsourced points. |
| Retention | Configurable on device; server retention policy documented per deployment. |

A DPIA is required before crowdsourcing (Phase 4) launches.

## In-app privacy notice — policy version 1.0

Shown on first launch and in **Privacy**. Changing this text requires a new
`privacyPolicyVersion` (`apps/mobile/lib/core/privacy.dart`), which asks every
user again (ADR-018).

**What OpenNetIQ measures**
- Mobile network: operator, network type (2G-5G), cell identifiers and signal
  levels of the serving and neighbouring cells.
- Location: GPS position, speed and accuracy while the signal monitor, a drive
  test or a speed/latency test is running.
- Test results: speed, latency, the test server used, phone model and Android
  version.

**Never collected**: phone number, IMEI, IMSI or SIM serial; contacts,
messages, call logs, photos or files; browsing history or traffic content.

**Where it goes**: measurements stay on the phone and leave it only when the
user exports a session and chooses where to share it. Speed and latency tests
connect to the configured test server, which sees the IP address. All
measurements can be deleted in-app at any time; the consent record is kept.

**Consent scopes in use (Phase 1)**: `location` and `radio`, granted or
withdrawn together ("Measure radio and location"). `background_location` and
`upload` are reserved for later phases; M-Lab ndt7 (publishes the IP address)
will get its own scope when the ndt7 client is built.
