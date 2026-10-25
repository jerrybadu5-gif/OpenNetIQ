# Voice and SMS tests — architecture

```
VoiceSmsScreen ─▶ VoiceSmsController (Riverpod Notifier)
                     │  consent gate: voiceSmsConsentProvider
                     │  settings: VoiceSmsSettingsController (app_settings)
                     │  link: TestContextService (drive / single-test session)
                     ├─▶ VoiceSmsEngine ── PlatformVoiceSmsEngine ── MethodChannel org.opennetiq/voice_sms
                     │                                                 └─ VoiceSmsBridge (Kotlin)
                     │                                                      ├─ CallProbe (Telecom + call log)
                     │                                                      ├─ SmsProbe (SmsManager + receivers)
                     │                                                      └─ VoiceSmsRules (pure outcome rules)
                     └─▶ VoiceSmsStore ── DriftVoiceSmsStore ── voice_sms_tests (schema v3)
ScriptRunner ─ ControllerStepExecutor: StepType.call / StepType.sms ─▶ VoiceSmsController.run
```

| Layer | Files |
|---|---|
| Domain | `domain/entities/voice_sms_test.dart`, `domain/repositories/voice_sms_repository.dart`, `ConsentScope.voiceSms` |
| Data | `data/repositories/platform_voice_sms_engine.dart`, `data/mappers/voice_sms_mapper.dart`, `data/local/drift_voice_sms_store.dart`, `tables.dart` (`VoiceSmsTests`), `app_database.dart` (v3 migration) |
| Application | `features/voice_sms/application/voice_sms_controller.dart` |
| Presentation | `features/voice_sms/presentation/voice_sms_screen.dart` (also `VoiceSmsConsentCard` on Privacy) |
| Native | `android/.../measurement/voice/*` |
| Export | `SessionExportBuilder.voiceSmsCsv`, GeoJSON `voice_sms_test` |

Migration v2 → v3: create `voice_sms_tests`; rebuild `consent_log` with the
`voice_sms` CHECK value (rows kept).
