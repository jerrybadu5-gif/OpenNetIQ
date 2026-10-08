# Drive Test — Testing

## Automated
| Suite | Covers |
|---|---|
| `test/domain/sample_gaps_test.dart` | Gap rule, pauses, completeness, edge cases |
| `test/data/platform_recording_service_test.dart` | Channel contract both directions (mocked platform, `handlePlatformMessage`) |
| `test/data/local/session_lifecycle_test.dart` | Pause/resume, sample timestamps, crash recovery SQL |
| `test/features/recording_controller_test.dart` | Lifecycle, options, pause accounting, notification throttling, Stop from notification, service failure, recovery-before-start |
| `test/features/recording_pipeline_test.dart` | Ticks stored with no screen, interval propagation, paused ticks dropped, recovery at startup |
| `test/features/drive_test_screen_test.dart`, `home_screen_test.dart`, `record_button_test.dart` | UI |
| `RecordingNotificationArgsTest.kt` | Kotlin argument validation |

```powershell
cd apps\mobile
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze --fatal-infos
flutter test
cd android; .\gradlew.bat testDevDebugUnitTest "-Ptarget=lib/main_dev.dart"; cd ..
```

## Device checks (Android 10+ phone with SIM)
1. `flutter run --flavor dev -t lib/main_dev.dart`. Home -> Drive test. Start at 1 s. Allow notifications.
2. Notification appears; text updates about every 5 s.
3. Lock the screen 5 min; unlock: sample count advanced ~300.
4. Swipe the app away from Recents; notification stays. Reopen from the notification: same session still counting.
5. Pause 1 min, Resume; Stop from the notification. Last-session card: Missing should be ~0 % and no gap for the pause.
6. Start, then kill the process (`adb shell am kill org.opennetiq.opennetiq_mobile.dev` after swiping away, or force-stop in Settings). Reopen: Sessions shows that session as `aborted`.
7. Acceptance run: 2 h, 1 s, screen off, battery exemption on. Pass: Missing <= 1 %, battery drop <= 30 % over 2 h, no crash.
