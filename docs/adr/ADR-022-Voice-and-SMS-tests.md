# ADR-022: Voice and SMS tests without a dialer role

## Context
#30 adds mobile-originated voice-call and SMS sequences (call setup success
and time, drops; SMS delivery) for regulator benchmarking (ETSI TS 102 250-2
KPIs). Android exposes precise call states (dialling / alerting / active)
only to the default dialer (`InCallService`) or privileged apps
(`READ_PRECISE_PHONE_STATE`). The app is sideloaded (no Play policy limits)
but must not replace the user's phone app. MOS/POLQA is out of scope.

## Decision
- Calls: `TelecomManager.placeCall` (CALL_PHONE), call presence polled with
  `isInCall` every 200 ms, released with `endCall` (ANSWER_PHONE_CALLS) at a
  fixed **window from dialling** (default 45 s). Answer is derived after the
  call from the call log's DURATION of the latest outgoing call
  (READ_CALL_LOG; only DATE/TYPE/DURATION are queried): setup time =
  window − connected (1 s resolution). Early end after connecting = drop.
- SMS: `SmsManager.sendTextMessage` with sent and delivery PendingIntents;
  loopback targets (own number) also time the arrival via `SMS_RECEIVED`,
  matching a random token in memory.
- One MethodChannel `org.opennetiq/voice_sms`; table `voice_sms_tests`
  (schema v3) storing only `target_masked` (last two digits), no message
  text. Numbers live in local settings (`voice_sms.settings.v1`) and are not
  exported.
- New consent scope `voice_sms` (privacy policy 1.1), separate opt-in,
  default off; the controller refuses to run without it. Schema v3 rebuilds
  `consent_log` (Drift `TableMigration`) for the new CHECK value.
- Script steps `call` and `sms` run the configured lines.

## Consequences
- Setup time has 1 s resolution and includes ringing; it is comparable
  between operators/phones with the same test line, not to drive-test tools
  that read layer-3 messages. Documented in methodology §6c.
- Without the call-log permission results are `partial` (no setup time).
- Drops require a test line that answers automatically and holds the call;
  a far-end hang-up before the window counts as a drop.
- Calls and SMS are chargeable and visible in the phone's own call log and
  messages; the in-app notice says so.
- Probes are verified on device; outcome rules (`VoiceSmsRules`) have JVM
  unit tests.
