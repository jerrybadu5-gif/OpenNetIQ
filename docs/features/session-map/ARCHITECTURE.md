# Session Map & Detail — Architecture

| Layer | Files |
|---|---|
| Domain | `entities/sample_point.dart`, `services/track_segments.dart`, `services/session_stats.dart`, `CellObservation.levelFor` |
| Data | `DriftMeasurementStore.loadSamplePoints` (2 queries: samples, serving cells; primary cell picked in Dart) |
| Application | `recording/application/live_track.dart` (in-memory points of the active session), `sessions/application/session_detail_providers.dart`, `map/application/map_tile_config.dart` |
| Presentation | `map/presentation/track_map.dart` (`TrackMap`, `TrackLegend`), `sessions/presentation/session_detail_screen.dart`, Drive test status map |

## Rendering 10 k points
- `TrackSegments.build` merges consecutive samples of the same class into one polyline: polylines scale with class changes, not samples (10 k samples alternating every 500 -> 20 polylines).
- Segments are cached per points list identity; the live list grows by one point per stored sample.
- flutter_map simplifies each polyline per zoom level (Douglas-Peucker, default 0.4 px tolerance) and culls off-screen lines.
- The live map never queries the database; the detail screen loads once (two indexed queries).

## Flow
```
RecordingController.onSnapshot -> recordSample (Drift) -> LiveTrack.add(TrackSegments.fromTick)
DriveTestStatus -> TrackMap(points: liveTrackProvider, follow: true)
SessionsScreen tile -> /sessions/:id -> sessionDetailProvider(id)
   -> getSession + loadSamplePoints -> SessionStats.of + SampleGaps.analyse
```
