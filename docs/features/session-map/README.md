# Session Map & Detail

Live drive-test map and session detail with summary statistics. Closes #18.

## What it does
- **Drive test screen**: live map above the recording status. The track is coloured by the primary serving cell's level class (Excellent / Good / Fair / Poor / No service, grey = no level). The camera follows the newest point.
- **Sessions -> tap a session**: detail screen with
  - map of the whole track (fitted to the route) and colour legend;
  - summary: status, type, start/end (local time), duration, samples, distance, interval, operator under test, methodology version;
  - completeness: expected, missing (%), gaps, longest gap, share of samples with a GPS position;
  - signal level per RAT, min / median / max (samples): 4G RSRP, 5G SS-RSRP, 3G RSCP, 2G RSSI;
  - signal-class distribution and network-type share;
  - delete (confirmation; removes the session with all samples and cell observations). Disabled while the session is recording.
- Primary cell = LTE anchor in 5G NSA, otherwise the first serving cell (same rule as the signal monitor).
- Points with no usable GPS fix or a mock location are never drawn; the line breaks across gaps longer than 30 s.

## Base map
OpenStreetMap standard tiles by default (attribution shown). For campaigns, use your own tile server:
```powershell
flutter run --flavor dev -t lib/main_dev.dart `
  --dart-define=ONQ_TILE_URL=https://tiles.example.org/{z}/{x}/{y}.png `
  --dart-define=ONQ_TILE_ATTRIBUTION="© OpenStreetMap contributors"
```
See ADR-015. Without network the track still draws on a blank background.

## Known limits
- The detail screen's gap count includes pauses (pause times are not stored in schema v1); the report shown right after Stop excludes them.
- Signal classes are display classes from MEASUREMENT-METHODOLOGY.md §4, not regulatory coverage thresholds.
