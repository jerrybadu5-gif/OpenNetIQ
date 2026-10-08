# Local Storage - Architecture

```
SignalMonitorScreen --ref.listen(radioSnapshotProvider)--> RecordingController.onSnapshot(radio, latest location)
RecordButton  -> RecordingController.start()/stop()            (Notifier, writes queued in order)
SessionsScreen -> sessionsProvider -> SessionRepository.watchSessions()

RecordingController
   DeviceInfoSource (MethodChannel getDeviceInfo) -> DeviceRegistry.ensureDevice()  (app_settings.device_id)
   SessionRepository.createSession/startRecording/finishRecording
   SampleRepository.recordSample  --> buildSampleRows() (pure) + SampleQuality (pure)
                                       transaction: INSERT samples, batch INSERT cell_observations,
                                       UPDATE sessions (sample_count, distance_m, updated_at, version)
DriftMeasurementStore / DriftDeviceRegistry  ->  AppDatabase (Drift, schema v1)  ->  SQLite (WAL, FK on)
```

| Topic | Decision |
|---|---|
| ORM | Drift (ADR-004); tables in `lib/data/local/tables.dart`, column names = data dictionary |
| Times | TEXT UTC ISO 8601 with milliseconds (`formatUtc`), same as Kotlin |
| Ids | UUIDv7 (`core/uuid7.dart`), device id random per install |
| Integrity | FK cascade session -> samples -> cells; CHECK constraints on enums; transaction per tick |
| Ordering | Controller queues writes so samples keep tick order |
| Performance | >= 50 samples/s (test), one transaction + one batch per tick |
| Generated code | `*.g.dart` gitignored; CI runs `build_runner` and excludes it from the coverage gate |
| Privacy | `allowBackup=false`; delete session / delete all in the UI |
| Migrations | `schemaVersion = 1`; future changes add Drift step migrations + ADR |
