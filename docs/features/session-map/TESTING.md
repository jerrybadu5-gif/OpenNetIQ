# Session Map & Detail — Testing

## Automated
| Suite | Covers |
|---|---|
| `test/domain/track_and_stats_test.dart` | Signal classes, segment runs and gap breaks, 10 k-point segmentation time, live tick conversion, level statistics and distributions |
| `test/data/local/sample_points_test.dart` | Stored points: positions, levels by RAT, NSA anchor rule, mock flag, empty session |
| `test/features/track_map_test.dart` | Placeholder, one polyline per run, legend labels, 10 k-point render, follow mode |
| `test/features/session_detail_screen_test.dart` | Summary, completeness, statistics, delete with confirmation, active and missing sessions |
| `test/features/recording_controller_test.dart` | Live track appended per stored sample and reset per session |
| `test/data/local/measurement_store_test.dart` | Delete cascades to samples and cell observations (acceptance) |

Tests disable the base map (`noTiles` fixture) so no network is used.

```powershell
cd apps\mobile
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze --fatal-infos
flutter test
```

## Device checks
1. Drive test -> Start (1 s). Walk or drive: the line appears, coloured by level; the camera follows.
2. Lock the screen for a few minutes; unlock: the track has continued.
3. Stop. Sessions -> open the session: route fitted on the map, statistics filled, legend shown.
4. Pan/zoom a long session (2 h at 1 s = 7 200 points): no stutter.
5. Delete from the detail screen: returns to the list; the session is gone.
6. Airplane mode: the track still draws without a base map.
