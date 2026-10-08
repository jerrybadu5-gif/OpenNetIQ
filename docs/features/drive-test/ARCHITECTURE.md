# Drive Test — Architecture

```
OpenNetIqApplication (process)            ADR-014
 ├─ FlutterEngine (cached "opennetiq_main") ── Dart isolate
 │     bootstrap.dart: ProviderContainer
 │       ├─ startRecordingRuntime()
 │       │    ├─ recordingPipelineProvider  (radio + location -> controller)
 │       │    └─ startupRecoveryProvider    (abort orphaned sessions)
 │       └─ RecordingController (Notifier)
 │            ├─ SessionRepository / SampleRepository (Drift, per-sample txn)
 │            ├─ RecordingService  ── control channel ──┐
 │            └─ SampleGaps (domain)                    │
 ├─ MeasurementBridge (Kotlin) <────────────────────────┘
 │     RadioCollector, LocationCollector, DriveTestService control
 └─ MainActivity (attaches/detaches; permission dialogs only)

DriveTestService (foreground, type=location)
  partial wake lock · ongoing notification · Stop action -> onStopRequested -> Dart
```

## Layers
| Layer | Files |
|---|---|
| Domain | `domain/repositories/recording_service.dart`, `domain/services/sample_gaps.dart`, `SessionRepository.pauseRecording/abortOrphanedSessions`, `SampleRepository.sampleTimestamps` |
| Data | `data/repositories/platform_recording_service.dart`, `data/local/drift_measurement_store.dart` |
| Application | `features/recording/application/{recording_controller,recording_pipeline,recording_providers}.dart` |
| Presentation | `features/drive_test/presentation/drive_test_screen.dart`, `RecordingBanner` (home), `RecordButton` |
| Native | `opennetiq_mobile/{OpenNetIqApplication,MainActivity}.kt`, `measurement/service/{DriveTestService,DriveTestServiceEvents,RecordingNotificationArgs}.kt`, `MeasurementBridge` |

## Key decisions
- The radio stream interval follows the open session (`radioIntervalProvider`); the dashboard uses 1 s otherwise.
- Radio and GNSS stay subscribed during pauses (GNSS stays warm); paused ticks are dropped by the controller.
- Notification text is updated at most every 5 s.
- If the service cannot start, recording continues in the foreground and the UI says so (never silent).
- Gap rule: consecutive samples more than 1.5 x interval apart (after removing pause time) form a gap; missing = round(step / interval) - 1.
