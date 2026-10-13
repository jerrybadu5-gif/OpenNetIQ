# API: session export (#23)

No platform channel, HTTP or schema changes. Column names follow
`docs/standards/DATA-DICTIONARY.md`; units are in the names.

## Samples CSV (`<base>.csv`)

| Columns | Source |
|---|---|
| `session_id, session_name, session_type, device_id, device_manufacturer, device_model, android_version, methodology_version` | `sessions`, `devices` (repeated per row for stand-alone use) |
| `measurement_id, timestamp, lat, lon, altitude_m, speed_mps, bearing_deg, h_accuracy_m, v_accuracy_m, satellites_used, gps_quality` | `samples` |
| `operator, mcc, mnc, sim_operator, network_type, data_state, is_roaming, radio_timestamp, quality_flag` | `samples` |
| `serving_rat, serving_mcc, serving_mnc, serving_lac_tac, serving_cell_id, serving_enb_id, serving_gnb_id, serving_local_cell_id, serving_pci_psc_bsic, serving_arfcn, serving_band, serving_bandwidth_khz, serving_rssi_dbm, serving_rscp_dbm, serving_ecno_db, serving_rsrp_dbm, serving_rsrq_db, serving_sinr_db, serving_cqi, serving_timing_advance, serving_quality_flag` | primary serving `cell_observations` row |
| `nr_cell_id, nr_gnb_id, nr_pci, nr_arfcn, nr_band, nr_ss_rsrp_dbm, nr_ss_rsrq_db, nr_ss_sinr_db, nr_csi_rsrp_dbm, nr_csi_rsrq_db, nr_csi_sinr_db` | serving NR leg (5G NSA) |
| `neighbour_count` | non-serving cells of the sample |

## Tests CSV (`<base>_tests.csv`)

`test_type` (`speed` / `latency`), `test_id, session_id, measurement_id,
timestamp, methodology_version, status, method` (speed method or latency
protocol), `target` (server host or host:port), `lat, lon, network_type`
(from the linked sample), speed KPIs `dl_*`, `ul_*`, `dns_ms,
tcp_connect_ms, streams, rat_changed`, latency KPIs `probes_sent,
probes_received, min_ms, max_ms, mean_ms, median_ms, p95_ms, jitter_ms,
packet_loss_pct, raw_rtts_ms` (JSON array, `null` = lost), `error`.
Columns that do not apply to a row are empty.

## GeoJSON (`<base>.geojson`)

`FeatureCollection`; every feature has `properties.feature_type`:

| `feature_type` | Geometry | Main properties |
|---|---|---|
| `track` | `LineString` [lon, lat] (null if < 2 fixes) | session metadata, `sample_count`, `samples_without_fix`, `distance_m` |
| `sample` | `Point` [lon, lat(, alt)] | network, serving cell ids and levels, NR leg levels |
| `speed_test` | `Point` of the linked sample, or null | status, server, `dl_mean_mbps`, `ul_mean_mbps` |
| `latency_test` | `Point` of the linked sample, or null | protocol, target, `median_ms`, `jitter_ms`, `packet_loss_pct` |

## Dart

`SessionExporter.export(sessionId, formats) → List<ExportedFile>`
(`StateError` for an unknown session); `FileSharer.share(files, subject:)`.
MIME types: `text/csv`, `application/geo+json`.
