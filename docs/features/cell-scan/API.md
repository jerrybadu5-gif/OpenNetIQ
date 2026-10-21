# API: cell scan (#27)

No platform channel or schema changes.

| Symbol | Contract |
|---|---|
| `CellSighting.cellKey` | `RAT:MCC-MNC:cellId`, else `RAT:aARFCN:pPCI` |
| `CellSighting.siteKey` | `LTE:MCC-MNC:enbN` / `NR:MCC-MNC:gnbN`, else the cell key |
| `CellLayerBuilder.build(sightings)` | cells sorted by band label then best level; sites; measurement → primary serving site (LTE anchor first) |
| `SiteEstimator.estimate(key, sightings)` | `EstimatedSite` with `method` (`timing_advance` / `level_centroid`), `uncertaintyM`, cells with optional `azimuthDeg` |
| `DriftCellStore.loadSightings({sessionId})` | time-ordered; mock/no-fix samples keep cell data without position |
| `ExportFormat.kml` | `<base>.kml`, MIME `application/vnd.google-earth.kml+xml` |

KML: `Document` › `Style q_<class>` (aabbggrr colours as the app legend),
folders *Track* (LineString per level-class run), *Samples* (Point +
TimeStamp, hidden), *Estimated sites* (Point, description = method,
uncertainty, cells and azimuths).
