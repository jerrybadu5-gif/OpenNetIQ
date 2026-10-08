# ADR-015: Base-map tiles for on-device maps

- Status: Accepted
- Date: 2026-10-09
- Deciders: OpenNetIQ core team
- Relates to: ADR-011 (flutter_map), roadmap 2.8 (offline tiles)

## Context
Drive-test maps (issue #18) need a base map. OpenStreetMap's standard tile server is free but governed by the OSM Tile Usage Policy: an identifying User-Agent, visible attribution, no bulk or offline prefetch, and no guarantee of capacity. Regulator field campaigns may run many devices at once and often in areas with no data coverage.

## Decision
- Use `flutter_map` `TileLayer` with OSM standard tiles **by default**, `userAgentPackageName = org.opennetiq.opennetiq_mobile`, and the "© OpenStreetMap contributors" attribution always shown.
- Make the tile source configurable at build time: `--dart-define=ONQ_TILE_URL=...` and `ONQ_TILE_ATTRIBUTION=...`, so a regulator or operator can point the app at its own tile server (e.g. a self-hosted OpenMapTiles/Martin instance).
- No tile prefetching. Only tiles the user views are requested (flutter_map's cache only).
- The track, legend and statistics never depend on tiles: with no network the line still draws on a blank background.

## Consequences
- Works out of the box for development and light field use, compliant with the OSM policy.
- Large campaigns must configure their own tile server; documented in `docs/features/session-map/README.md`.
- Offline base maps (MBTiles/PMTiles) remain roadmap item 2.8.
