# Architecture: customer-experience tests (#29)

```
Kotlin  measurement/qoe/
  HttpProbe.kt          OkHttp + TimingListener (app reachability, file transfer)
  NavigationTiming.kt   JS snippet + parser (web)
  WebPageProbe.kt       off-screen WebView, empty cache (web)
  PlaybackStats.kt      start delay / rebuffer / played / bitrate accumulator
  VideoProbe.kt         ExoPlayer (stream) or WebView + <video> hooks (page)
  QoeBridge.kt          MethodChannel org.opennetiq/qoe (web, video, app, file, cancel)
Dart
  domain/entities/qoe_test.dart              QoeKind, VideoMode, QoeTarget, QoeSettings, QoeResult, QoeRecord
  domain/repositories/qoe_repository.dart    QoeEngine, QoeStore
  data/repositories/platform_qoe_engine.dart, data/mappers/qoe_mapper.dart
  data/local/drift_qoe_store.dart            qoe_tests (schema v2)
  features/qoe/application/qoe_controller.dart   settings (app_settings JSON), run/cancel, history
  features/qoe/presentation/qoe_test_screen.dart
```

- `QoeTestController.run(kinds)` plans targets in kind order (file: download
  then upload), links once to the drive/session at the first saved result,
  stores each result immediately; cancel drops the interrupted target.
- Scripts: `StepType.web/video/apps/file` → `QoeTestController.run({kind})`.
- Export: `_qoe.csv`, GeoJSON `qoe_test`; "Delete all measurement data"
  clears `qoe_tests`.
- Schema v2 migration: `onUpgrade` creates `qoe_tests` for v1 databases.
