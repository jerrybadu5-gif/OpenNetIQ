# Voice and SMS tests (issue #30)

**Home → Voice and SMS tests.** Switch on *Allow voice and SMS tests*
(separate consent, policy 1.1), grant the Android permissions, add test
numbers, pick *Voice call* and/or *SMS*, tap *Start tests*.

| Test | What it measures (defaults) |
|---|---|
| Voice call | Dials each call line, keeps the call 45 s from dialling, hangs up. Outcome (completed, dropped, no answer, rejected, not placed), setup time, connected time |
| SMS | Sends a tagged SMS to each SMS line. Sent-report and delivery-report times; for `self` lines also the arrival time. Timeout 60 s |

- **Numbers**: one per line `Name | number`. Add `| self` to an SMS line with
  this phone's own number to measure end-to-end delivery. Use a call line
  that answers automatically and holds the call (otherwise a far-end hang-up
  counts as a drop).
- **Options**: call length from dialling (10–600 s), SMS timeout (5–600 s).
- **Permissions**: calls, ending calls, call log (for the setup time; without
  it results are *partial*), send and receive SMS.
- Results keep only the last two digits of the number; message text is never
  stored. Calls and SMS are charged normally and appear in the phone's call
  log and messages.
- Works in **test scripts** (Voice call, SMS steps) and during drive
  recordings; exported as `<session>_voice_sms.csv` and `voice_sms_test`
  GeoJSON features.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md),
ADR-022, MEASUREMENT-METHODOLOGY.md §6c.
