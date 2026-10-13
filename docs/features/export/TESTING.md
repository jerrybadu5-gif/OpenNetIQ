# Testing: session export (#23)

## Automated
- `test/data/export/csv_test.dart`: null/bool/NaN handling, quoting, CRLF.
- `test/data/export/session_export_test.dart` (in-memory Drift): row order,
  column count per row, NSA anchor/NR-leg split, neighbour count, no-fix
  sample, tests CSV, GeoJSON structure and coordinate order, file names,
  file writing and replacement, unknown session.
- `test/features/session_export_test.dart`: controller success/failures,
  sheet picks formats and reports, dismiss does nothing.
- `session_detail_screen_test.dart`: Export only on finished sessions.

## On device
1. Record a short drive (with one speed test during it), stop.
2. Sessions → the session → share icon → **CSV + GeoJSON** → save to Files
   or Drive.
3. Open the CSV in Excel: one row per second, empty cells (not 0) where
   values are unavailable.
4. Open the GeoJSON in QGIS (or geojson.io): track line, sample points,
   test point; check points sit on the road you drove.
