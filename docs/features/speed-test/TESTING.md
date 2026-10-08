# Speed Test Engine — Testing

## Automated
| Suite | Covers |
|---|---|
| `ThroughputMathTest.kt` | Interval rate, ramp-up exclusion, time-weighted mean, nearest-rank P10/median/P90, 1 s peak, live rate, sampler, status rule |
| `SpeedTestConfigTest.kt` | URL normalisation, endpoints, defaults, rejection of bad input |
| `SpeedTestEngineTest.kt` | End to end against an in-process server: both directions, phases/progress, cancel within 3 s, HTTP 500, DNS failure, cancel before run |
| `test/data/speed_test_engine_test.dart` | Event mapping, channel arguments, error mapping, cancel propagates |
| `test/data/local/speed_test_store_test.dart` | All columns round-trip, failed tests, ordering, settings |
| `test/features/speed_test_controller_test.dart` | Run with snapshot + `single_test` session, RAT change flag, cancel stores nothing, errors, drive-session linking, no radio access |
| `test/features/speed_test_screen_test.dart` | Server validation/save, start/cancel, live rate, result and error cards |

```powershell
cd apps\mobile
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze --fatal-infos
flutter test
cd android; .\gradlew.bat testDevDebugUnitTest "-Ptarget=lib/main_dev.dart"; cd ..
```

## Device check (dev server on your PC)
1. PC and phone on the same Wi-Fi. `python scripts\speedtest_dev_server.py --port 8080` (allow it through Windows Firewall).
2. `flutter run --flavor dev -t lib/main_dev.dart`. Home -> Speed test. Server `http://<PC IP>:8080/backend/`, Save, Start.
3. Phases Download then Upload, rate updates ~10x/s, result card after ~25 s.
4. Start again and Cancel during download: stops at once, no result.
5. Sessions: a `Single test` session with 1 sample appears for each completed test.
6. Wrong URL (e.g. port 9999): `failed` with the reason.

## Accuracy validation (acceptance: within ±10 % of reference, n >= 30)
Run on mobile data with a server reachable by both apps (or compare against a reference tool using the same server):
1. Same phone, same location, stationary, alternate OpenNetIQ and the reference test 30 times each (A/B/A/B…), 1 min apart.
2. Record download and upload mean of each run.
3. Pass if the median of OpenNetIQ / reference ratios is within 0.90–1.10 for both directions.
Results go to `docs/validation/` with the field campaign (#25).
