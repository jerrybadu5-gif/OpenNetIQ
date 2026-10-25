# Testing: cell scan (#27)

## Automated
- `test/domain/cell_layer_builder_test.dart`: synthetic site recovered
  within 150 m from TA on an L-shaped drive; straight road falls back to
  centroid; no-TA centroid; three sectors share one site with azimuths
  within 30°; neighbour resolution; NSA primary serving.
- `test/data/local/cell_store_test.dart`: join, mock/no-fix handling,
  provider wiring.
- `test/data/export/kml_test.dart`: escaping, folders, coordinates, file.
- `test/features/cell_scan_screen_test.dart`: grouping, sites, empty/error,
  tap-to-serving line, serving lines toggle.

## On device
1. Drive a loop around a known site (e.g. a tower you can see), 10–15 min.
2. Home → Cell scan: cells grouped by band; the serving cell has the most
   serving samples.
3. Open the session: tower icon with circle; tap the track → line to the
   serving site; compare the estimate with the real tower (note the method
   and distance).
4. Export → KML → open in Google Earth: coloured track and site marker.
