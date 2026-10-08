import 'package:opennetiq_mobile/features/map/application/map_tile_config.dart';

/// Base map off: no network tiles in tests.
final noTiles = mapTileConfigProvider.overrideWithValue(
  const MapTileConfig(urlTemplate: '', attribution: '', enabled: false),
);
