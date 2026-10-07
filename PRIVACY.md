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
