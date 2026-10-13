# Consent and privacy (issue #24)

- **First launch**: a consent screen (privacy notice, policy 1.0) is shown
  before anything else. *Agree and continue* logs consent and then shows the
  Android permission prompts. *Not now* opens the app with measurement off;
  speed and latency tests still run, unlinked from radio and location.
- **Home → Privacy** (shield icon): switch *Measure radio and location* on or
  off, read the notice, delete all measurement data, see the consent history.
- Without consent the signal monitor and drive test show *Measurement is
  switched off* with a link to Privacy; nothing is read from the radio or GPS
  even if Android permissions are still granted.
- Changing consent or deleting data is blocked while a recording runs.
- A new privacy-policy version asks every user again.

Notice text: [PRIVACY.md](../../../PRIVACY.md). Decision: [ADR-018](../../adr/ADR-018-Consent-gate-and-ledger.md).
See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md).
