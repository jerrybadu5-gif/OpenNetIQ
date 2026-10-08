# Location - Testing

## Automated
| Suite | File | Covers |
|---|---|---|
| Kotlin unit | `android/app/src/test/kotlin/org/opennetiq/measurement/location/LocationRulesTest.kt` | Validation, quality thresholds, status assembly, payload keys (6 tests) |
| Dart mapper | `test/data/location_mapper_test.dart` | Full mapping, optional fields, strict type errors |
| Dart repository | `test/data/platform_location_repository_test.dart` | Mocked EventChannel, interval argument, error translation |
| Widget | `test/features/location_card_test.dart` | Fix, poor/mock, searching, Location off, error, loading |
| Widget | `test/features/signal_monitor_screen_test.dart` | GPS starts only after permission; card on the dashboard |

```powershell
cd apps\mobile
flutter analyze --fatal-infos
flutter test --coverage
cd android; .\gradlew.bat testDevDebugUnitTest "-Ptarget=lib/main_dev.dart"; cd ..
```

## Manual (phone)
1. Outdoors: Signal monitor -> GPS card shows `Good`, accuracy under 10 m, satellites e.g. `9 / 14` within a minute.
2. Compare coordinates with Google Maps / another GPS app: within the reported accuracy.
3. Walk or drive: speed and bearing update; fix age stays under 2 s.
4. Indoors: quality drops to `Poor` or `Searching for GPS fix`.
5. Switch Location off in quick settings: card shows `Location is off`; switch on: recovers.
6. Optional: enable a mock-location app in Developer options: card shows the MOCK_LOCATION warning.
