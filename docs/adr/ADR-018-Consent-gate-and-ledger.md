# ADR-018: Consent gate and append-only consent ledger

## Context
ROADMAP 1.9 requires consent before any location/radio collection.
Android runtime permissions are not consent: they can be granted for other
reasons, cannot be withdrawn from inside the app, and leave no record of
what the user was told. Regulators need proof of what was accepted, when,
and under which policy text.

## Decision
- `consent_log` is append-only. The current decision per scope is the latest
  row for the current `privacyPolicyVersion`; a new policy version asks again.
- The app shows only the consent screen until the user answered (gate in
  `OpenNetIqApp`). Android permission prompts appear only after "Agree".
- Phase 1 uses one decision, "Measure radio and location", logged as two rows
  (`location`, `radio`).
- Consent is enforced in one place: `RadioPermissions.consent`. Without it,
  `canMonitor`/`canLocate` are false, so radio, GNSS, recording and test
  snapshots stop even if Android permissions remain granted.
- Withdrawal and "Delete all measurement data" are blocked while recording.
  Deletion keeps the ledger (proof of consent) and the random device id.
- M-Lab ndt7 consent (ADR-016) gets its own scope, with a schema migration,
  when the ndt7 client is implemented; no UI for a feature that does not exist.

## Consequences
- Decline still allows speed/latency tests, unlinked from radio/location.
- If the ledger cannot be read, the app opens with measurement off (fail
  closed).
- Reworded privacy text must bump `privacyPolicyVersion`.
