# Architecture: cell scan (#27)

```
domain/entities/cell_scan.dart            CellSighting, ScannedCell, EstimatedSite/Cell, CellLayer
domain/services/cell_layer_builder.dart   CellLayerBuilder (scan, neighbour resolution, primary serving)
                                          SiteEstimator (TA Gauss-Newton, level centroid, azimuth)
data/local/drift_cell_store.dart          cell_observations ⨝ samples -> CellSighting
data/export/kml_builder.dart              KML 2.2 (track segments, samples, sites)
features/cells/application/cell_layer_providers.dart   cellLayerProvider(sessionId?)
features/cells/presentation/cell_scan_screen.dart       list + map
features/map/presentation/track_map.dart                site layer, tap-to-serving line, serving lines
```

- No schema change: everything is derived from stored observations.
- `cellLayerProvider(id)`: cells and serving map from the session; sites
  from all sessions filtered to the session's sites.
- `SamplePoint.measurementId` links track points to their serving site.
- The KML export uses only the exported session's data (self-contained file).
