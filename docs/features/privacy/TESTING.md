# Testing: consent and privacy (#24)

## Automated
- `test/domain/consent_test.dart`: ledger folding, policy versions, scope
  wire values, `withConsent`.
- `test/data/local/consent_store_test.dart`: rows per scope, ledger order,
  erase keeps ledger and device, malformed rows skipped.
- `test/features/privacy/consent_flow_test.dart`: controller on Drift;
  permissions follow consent (no Android prompt without it); first-run gate
  (agree / not now / already decided); signal monitor prompt; privacy screen
  switch, recording lock, delete confirm/failure, ledger.
- Existing feature tests run with `grantedConsentOverride`.

## On device
1. Uninstall, install, open: the consent screen appears first; nothing else.
2. *Not now* → Home; Signal monitor shows *Measurement is switched off*.
   Speed test still runs.
3. Home → Privacy → switch on → Android permission prompts → Signal monitor
   shows live data.
4. Start a drive recording → Privacy: switch and delete are locked. Stop.
5. Privacy → Delete all measurement data → Sessions list is empty; consent
   history still lists your decisions.
