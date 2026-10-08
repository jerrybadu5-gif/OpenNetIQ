# ADR-014: Application-owned Flutter engine for background recording

- Status: Accepted
- Date: 2026-10-08
- Deciders: OpenNetIQ core team
- Relates to: ADR-004 (Drift), ADR-005 (Kotlin measurement layer), ADR-013 (channels)

## Context
Drive tests (issue #17) must keep recording for hours with the screen off and survive the user swiping the task away. Samples are written by the Dart session engine (Drift, ADR-004). With the default embedding, `FlutterActivity` owns the engine: when the activity is destroyed, the Dart isolate stops and recording stops with it, even if a foreground service keeps the process alive.

Options:
1. Move the whole session engine (sampling + SQLite writes) to Kotlin; Dart only reads.
2. Run a second, headless Flutter engine inside the service.
3. Create the single engine in `Application`, cache it, and let `MainActivity` attach to it; a foreground service keeps the process alive.

## Decision
Option 3.
- `OpenNetIqApplication` creates the `FlutterEngine`, registers `MeasurementBridge`, runs the Dart entrypoint and puts the engine in `FlutterEngineCache` (`opennetiq_main`).
- `MainActivity` uses the cached engine and does not destroy it (`shouldDestroyEngineWithHost() = false`); it attaches to the bridge only for permission dialogs.
- `DriveTestService` is a foreground service of type `location`, started from the visible app (no `ACCESS_BACKGROUND_LOCATION`), holding a partial wake lock (12 h cap) and the ongoing notification with a Stop action.
- The Dart `recordingPipelineProvider` lives in the root `ProviderContainer` (created in `bootstrap.dart`), not in a screen, so ticks are stored whatever is on screen.
- The service is `START_NOT_STICKY`. A killed process cannot resume a session; on the next start the session is closed as `aborted` at its last sample (crash recovery).

## Consequences
- One code path for foreground and background recording; Drift stays the only writer (no cross-engine SQLite locking).
- The Dart isolate keeps running while the activity is gone; idle cost is low because radio and GNSS streams are only subscribed by visible screens or an open session.
- Reopening the app restores the last route (engine state is kept).
- `foregroundServiceType="dataSync"` from the roadmap is not used: Android 15 limits `dataSync` to 6 h/day and speed tests run inside the `location` service in M1.
- Option 1 remains the fallback if field tests show Dart-side gaps under OEM battery managers.
