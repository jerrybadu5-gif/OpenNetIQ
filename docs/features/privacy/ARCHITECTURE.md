# Architecture: consent and privacy (#24)

```
core/privacy.dart                                  privacyPolicyVersion
domain/entities/consent.dart                       ConsentScope, ConsentRecord, ConsentStatus
domain/repositories/consent_repository.dart        ConsentRepository, MeasurementDataEraser
data/local/drift_consent_store.dart                consent_log (append-only), erase
features/privacy/application/consent_controller.dart
    consentProvider (AsyncNotifier) · measurementConsentProvider · consentLedgerProvider
features/privacy/presentation/
    consent_screen.dart   first-run gate (OpenNetIqApp shows it until decided)
    privacy_screen.dart   switch, delete all, ledger
    privacy_summary.dart  notice text, ConsentPrompt
```

Enforcement path:

```
consent_log → consentProvider → measurementConsentProvider
  → RadioPermissionsController.build(): permissions.withConsent(...)
      → canMonitor / canLocate
          → radioSnapshotProvider, locationStatusProvider (empty streams)
              → recording, signal monitor, drive test, test snapshots
```

`request()` never shows Android prompts without consent. No schema change:
`consent_log` existed since schema v1.
