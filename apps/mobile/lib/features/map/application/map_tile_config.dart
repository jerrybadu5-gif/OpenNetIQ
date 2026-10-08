import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base-map tiles (ADR-015). Defaults to OpenStreetMap standard tiles;
/// deployments (e.g. a regulator-hosted tile server) override with
/// `--dart-define=ONQ_TILE_URL=... --dart-define=ONQ_TILE_ATTRIBUTION=...`.
class MapTileConfig {
  const MapTileConfig({
    required this.urlTemplate,
    required this.attribution,
    this.enabled = true,
  });

  static const MapTileConfig fromEnvironment = MapTileConfig(
    urlTemplate: String.fromEnvironment(
      'ONQ_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    attribution: String.fromEnvironment(
      'ONQ_TILE_ATTRIBUTION',
      defaultValue: '© OpenStreetMap contributors',
    ),
  );

  /// Identifies the app to tile servers (OSM tile usage policy).
  static const String userAgentPackageName = 'org.opennetiq.opennetiq_mobile';

  final String urlTemplate;
  final String attribution;

  /// False draws the track without a base map (tests, offline fallback).
  final bool enabled;
}

final mapTileConfigProvider = Provider<MapTileConfig>(
  (ref) => MapTileConfig.fromEnvironment,
);
