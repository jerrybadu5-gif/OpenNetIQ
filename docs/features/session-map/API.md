# Session Map & Detail — API

No new platform-channel methods.

## Repository
`SampleRepository.loadSamplePoints(sessionId) -> List<SamplePoint>` (oldest first):

| Field | Source |
|---|---|
| `timestamp` | `samples.timestamp` |
| `lat`, `lon` | `samples.lat/lon` (usable fixes only) |
| `mockLocation` | `MOCK_LOCATION` in `samples.quality_flag` |
| `gpsQuality` | `samples.gps_quality` |
| `networkType` | `samples.network_type` |
| `rat`, `levelDbm` | primary serving `cell_observations` row: RSRP (LTE/NR), RSCP (WCDMA), RSSI (GSM) |

## Routes
| Path | Screen |
|---|---|
| `/drive` | Drive test (live map) |
| `/sessions/:id` | Session detail |

## Build-time configuration
| `--dart-define` | Default |
|---|---|
| `ONQ_TILE_URL` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |
| `ONQ_TILE_ATTRIBUTION` | `© OpenStreetMap contributors` |
