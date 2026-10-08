# Local Storage - Testing

## Automated (in-memory SQLite)
| Suite | File | Covers |
|---|---|---|
| Schema | `test/data/local/schema_test.dart` | Parses `schema_v1.sql`; every table/column/type/NOT NULL matches; indexes; FK on; CHECK constraints |
| Store | `test/data/local/measurement_store_test.dart` | Session lifecycle, watch, delete cascade, sample + cell mapping, flags, distance, throughput >= 50 samples/s |
| Device | `test/data/local/device_registry_test.dart` | Random id once, upgrade updates details |
| Quality | `test/domain/sample_quality_test.dart` | Haversine, location/radio skew, flag merge, distance eligibility |
| Controller | `test/features/recording_controller_test.dart` | Start/record/stop, ordering, errors surfaced |
| Widgets | `test/features/sessions_screen_test.dart`, `record_button_test.dart` | List, delete confirmations, REC counter |

```powershell
cd apps\mobile
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-infos
flutter test --coverage
```

## Manual (phone)
1. Signal monitor -> tap the record button -> `REC 0` counts up once per second.
2. Walk 2-3 minutes outdoors, tap `REC n` to stop.
3. Home -> Sessions: the session shows the sample count (~ seconds recorded), distance and duration.
4. Back button while recording shows "Stop recording before leaving this screen."
5. Force-close and reopen the app: the session is still listed (persisted).
6. Delete the session; delete all.
