# Privacy by Design

| Principle | Implementation |
|---|---|
| Data minimisation | No IMEI, IMSI, MSISDN, own phone number, contacts, message text, photos or user content. Tested numbers keep only their last two digits. Device = random install UUID. |
| Consent | Explicit, versioned consent (logged in `consent_log`) before location, radio, voice/SMS tests, background-location and upload. |
| Local-first | Phase 1 stores everything on the device only. Nothing leaves the device unless the user exports or (Phase 2+) uploads. |
| Control | Delete any session or all data in-app; export your data at any time. |
| Publication (Phase 4) | Public maps use H3 aggregates with k-anonymity (k >= 5); location fuzzing for crowdsourced points. |
| Retention | Configurable on device; server retention policy documented per deployment. |

A DPIA is required before crowdsourcing (Phase 4) launches.

## In-app privacy notice — policy version 1.1

Shown on first launch and in **Privacy**. Changing this text requires a new
`privacyPolicyVersion` (`apps/mobile/lib/core/privacy.dart`), which asks every
user again (ADR-018). 1.1 (issue #30) adds the voice/SMS tests and the
third-party sites of the experience tests.

**What OpenNetIQ measures**
- Mobile network: operator, network type (2G-5G), cell identifiers and signal
  levels of the serving and neighbouring cells.
- Location: GPS position, speed and accuracy while the signal monitor, a drive
  test or a test is running.
- Test results: speed, latency, web, video, app and file tests, the test
  server used, phone model and Android version.
- Voice and SMS tests, **only if the user allows them** (separate switch):
  call setup time, connected time and drops, SMS send/delivery/arrival times.
  The call log is read only for the duration of the test call (DATE, TYPE and
  DURATION columns of the latest outgoing call, never the number).

**Never collected**: own phone number, IMEI, IMSI or SIM serial; contacts,
message text, other calls, photos or files; browsing history or traffic
content. Numbers configured for voice/SMS tests stay in the app's settings;
results and exports keep only their last two digits.

**Where it goes**: measurements stay on the phone and leave it only when the
user exports a session and chooses where to share it. Speed and latency tests
connect to the configured test server; web, video and app tests connect to
the sites the user lists. They see the IP address. Test calls and SMS are
normal chargeable services. All measurements can be deleted in-app at any
time; the consent record is kept.

**Consent scopes in use**: `location` and `radio`, granted or withdrawn
together ("Measure radio and location", onboarding); `voice_sms`, a separate
opt-in (default off) on the Voice and SMS screen and in Privacy; voice/SMS
tests refuse to run without it. `background_location` and `upload` are
reserved for later phases; M-Lab ndt7 (publishes the IP address) will get its
own scope when the ndt7 client is built.

### History
- 1.0 (issue #24): radio, location, speed/latency tests.
- 1.1 (issue #30): voice/SMS tests (`voice_sms` scope, call-log duration
  read), experience tests' third-party sites.
