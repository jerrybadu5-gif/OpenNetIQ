# Signal Monitor - Testing

## Automated
| Suite | File | Covers |
|---|---|---|
| Kotlin unit (JUnit 4) | `android/app/src/test/kotlin/org/opennetiq/measurement/radio/RadioMappingTest.kt` | eNB/gNB derivation, all four RAT factories, UNAVAILABLE/out-of-range rules and flags, network-type resolution incl. NSA, PLMN split, payload keys (22 tests) |
| Dart domain | `test/domain/radio_domain_test.dart` | Enums, labels, primary cell / NR leg selection, quality classes, permissions |
| Dart mapper | `test/data/radio_snapshot_mapper_test.dart` | Full payload mapping, forward compatibility, strict type errors |
| Dart repository | `test/data/platform_radio_repository_test.dart` | Mocked MethodChannel/EventChannel, interval argument, error translation |
| Dart history | `test/features/signal_history_test.dart` | Rolling window |
| Widget | `test/features/signal_monitor_screen_test.dart` | Permission flow, LTE and NSA dashboards, warnings, empty/error states, navigation from home |

```powershell
cd apps\mobile
flutter analyze --fatal-infos
flutter test --coverage
cd android; .\gradlew testDevDebugUnitTest; cd ..
```

## Manual (on a phone with a SIM)
1. Home -> Signal monitor -> Grant access -> allow **Precise** location and phone access.
2. Serving card updates every second; values match another app (e.g. Network Cell Info) within about 2 dB.
3. Walk/drive: trend chart moves; neighbours re-order.
4. Airplane mode: "No serving cell" / network type No service; disable airplane mode and it recovers.
5. On a 5G NSA site (Android 11+): chip shows `5G NSA (5G)`, LTE anchor and NR leg cards.
6. Revoke location in Android settings while open: "Permission required" message.
7. Leave the screen: radio polling stops (no ongoing battery drain).
