# API: consent and privacy (#24)

No platform channel or HTTP changes; uses `consent_log` (DATA-DICTIONARY.md).

| Symbol | Contract |
|---|---|
| `privacyPolicyVersion` | `'1.0'`; bump when the notice changes |
| `ConsentStatus.fromLedger(version, ledger)` | latest row per scope for `version` |
| `ConsentStatus.decided` | both `location` and `radio` answered for the version |
| `ConsentStatus.measurement` | both granted |
| `ConsentRepository.record(scopes, granted:, policyVersion:)` | one row per scope, same timestamp, one batch |
| `ConsentRepository.ledger()` | newest first; unknown scopes/timestamps skipped |
| `MeasurementDataEraser.eraseMeasurements()` | deletes speed/latency tests, sessions (cascade samples, cells) in one transaction; keeps `consent_log`, `devices`, `app_settings` |
| `ConsentController.setMeasurement(granted:)` | logs `location` + `radio`, reloads |
| `measurementConsentProvider` | `false` until the ledger is read (fail closed) |
| `RadioPermissions.consent`, `canLocate`, `withConsent()` | consent folded into permission state |
