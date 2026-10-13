# Session export (issue #23)

Session detail → **Export** (share icon, finished sessions only) →
**CSV**, **GeoJSON** or **CSV + GeoJSON** → Android share sheet (Drive,
e-mail, Files, Bluetooth...).

| File | Content |
|---|---|
| `opennetiq_<name>_<UTC start>.csv` | One row per sample: GNSS, network, serving cell, NR leg (NSA), neighbour count |
| `opennetiq_<name>_<UTC start>_tests.csv` | Speed and latency tests of the session (only when there are any) |
| `opennetiq_<name>_<UTC start>.geojson` | RFC 7946: session track (`LineString`), one `Point` per located sample, test points |

- Raw stored values, unchanged; unavailable values are empty, never 0.
- Times are UTC ISO 8601 (`2026-10-13T01:00:01.000Z`). Coordinates WGS 84.
- Samples without a GNSS fix are in the CSV (empty `lat`/`lon`) but not
  drawn in GeoJSON; the track feature reports `samples_without_fix`.
- Files are written to the app cache (`exports/`, replaced on each export)
  and leave the device only through the share sheet the user chooses.

Opening in QGIS: *Layer → Add Layer → Add Vector Layer* for the GeoJSON, or
*Add Delimited Text Layer* for the CSV with X = `lon`, Y = `lat`, EPSG:4326.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md),
[ADR-017](../../adr/ADR-017-Share-sheet-export.md).
