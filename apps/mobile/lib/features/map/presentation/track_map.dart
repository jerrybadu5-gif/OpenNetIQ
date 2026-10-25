import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/services/track_segments.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';
import 'package:opennetiq_mobile/features/map/application/map_tile_config.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/signal_colors.dart';

/// Colour of track segments without a serving-cell level.
const Color unknownLevelColor = Color(0xFF757575);

Color trackColor(SignalQuality? quality) =>
    quality == null ? unknownLevelColor : signalQualityColor(quality);

/// Drive-test track coloured by serving-cell level class (issue #18).
/// With [follow] the camera keeps the newest point in view.
class TrackMap extends ConsumerStatefulWidget {
  const TrackMap({
    required this.points,
    this.follow = false,
    this.height = 280,
    this.layer,
    super.key,
  });

  final List<SamplePoint> points;

  /// Estimated sites and the serving site of each sample (issue #27).
  final CellLayer? layer;
  final bool follow;
  final double height;

  /// Default view (Port Moresby) before any fix.
  static const LatLng defaultCenter = LatLng(-9.4438, 147.1803);

  @override
  ConsumerState<TrackMap> createState() => _TrackMapState();
}

class _TrackMapState extends ConsumerState<TrackMap> {
  final MapController _controller = MapController();
  bool _ready = false;
  bool _servingLines = false;
  SamplePoint? _selected;
  List<SamplePoint>? _cachedFor;
  List<TrackSegment> _segments = const [];

  List<TrackSegment> _segmentsFor(List<SamplePoint> points) {
    if (!identical(points, _cachedFor)) {
      _cachedFor = points;
      _segments = TrackSegments.build(points);
    }
    return _segments;
  }

  static LatLng _latLng(SamplePoint p) => LatLng(p.lat!, p.lon!);

  SamplePoint? get _last {
    for (var i = widget.points.length - 1; i >= 0; i--) {
      if (widget.points[i].hasPosition) return widget.points[i];
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant TrackMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final last = _last;
    if (widget.follow && _ready && last != null) {
      _controller.move(_latLng(last), _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sample closest to [at] within 60 m, to show its serving-cell line.
  void _select(LatLng at) {
    if (widget.layer == null) return;
    const distance = Distance();
    SamplePoint? best;
    var bestM = 60.0;
    for (final p in widget.points) {
      if (!p.hasPosition) continue;
      final m = distance.as(LengthUnit.Meter, at, _latLng(p));
      if (m < bestM) {
        bestM = m;
        best = p;
      }
    }
    setState(() => _selected = best);
  }

  EstimatedSite? _servingSite(SamplePoint p) {
    final layer = widget.layer;
    final id = p.measurementId;
    if (layer == null || id == null) return null;
    final key = layer.servingSiteByMeasurement[id];
    return key == null ? null : layer.site(key);
  }

  static LatLng _sitePoint(EstimatedSite s) => LatLng(s.lat, s.lon);

  /// Short line from the site towards the sector's estimated azimuth.
  static List<LatLng> _sectorLine(EstimatedSite s, double azimuthDeg) {
    final length = s.uncertaintyM.clamp(150, 400).toDouble();
    final end = const Distance().offset(_sitePoint(s), length, azimuthDeg);
    return [_sitePoint(s), end];
  }

  List<Polyline<Object>> _servingPolylines(Color color) {
    final lines = <Polyline<Object>>[];
    final positioned = [
      for (final p in widget.points)
        if (p.hasPosition) p,
    ];
    final step = (positioned.length / 300).ceil().clamp(1, 1 << 20);
    for (var i = 0; i < positioned.length; i += step) {
      final site = _servingSite(positioned[i]);
      if (site == null) continue;
      lines.add(
        Polyline<Object>(
          points: [_latLng(positioned[i]), _sitePoint(site)],
          color: color.withValues(alpha: 0.35),
          strokeWidth: 1,
        ),
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mapTileConfigProvider);
    final layer = widget.layer;
    // Defensive: never let an invalid position reach the map camera.
    final sites = [
      for (final s in layer?.sites ?? const <EstimatedSite>[])
        if (s.lat.isFinite &&
            s.lon.isFinite &&
            s.lat.abs() <= 90 &&
            s.lon.abs() <= 180 &&
            s.uncertaintyM.isFinite)
          s,
    ];
    final selected = _selected;
    final selectedSite = selected == null ? null : _servingSite(selected);
    final scheme = Theme.of(context).colorScheme;
    final segments = _segmentsFor(widget.points);
    final last = _last;
    final positioned = [
      for (final p in widget.points)
        if (p.hasPosition) _latLng(p),
      for (final s in sites) _sitePoint(s),
    ];
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: last == null
                    ? TrackMap.defaultCenter
                    : _latLng(last),
                initialZoom: last == null ? 6 : 16,
                initialCameraFit: !widget.follow && positioned.length >= 2
                    ? CameraFit.coordinates(
                        coordinates: positioned,
                        padding: const EdgeInsets.all(32),
                        maxZoom: 17,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () => _ready = true,
                onTap: (_, at) => _select(at),
              ),
              children: [
                if (config.enabled)
                  TileLayer(
                    urlTemplate: config.urlTemplate,
                    userAgentPackageName: MapTileConfig.userAgentPackageName,
                  ),
                PolylineLayer<Object>(
                  polylines: [
                    for (final s in segments)
                      if (s.points.length >= 2)
                        Polyline<Object>(
                          points: [for (final p in s.points) _latLng(p)],
                          color: trackColor(s.quality),
                          strokeWidth: 5,
                        ),
                  ],
                ),
                if (sites.isNotEmpty) ...[
                  CircleLayer<Object>(
                    circles: [
                      for (final s in sites)
                        CircleMarker<Object>(
                          point: _sitePoint(s),
                          radius: s.uncertaintyM,
                          useRadiusInMeter: true,
                          color: scheme.primary.withValues(alpha: 0.06),
                          borderColor: scheme.primary.withValues(alpha: 0.4),
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),
                  PolylineLayer<Object>(
                    polylines: [
                      if (_servingLines) ..._servingPolylines(scheme.primary),
                      for (final s in sites)
                        for (final c in s.cells)
                          if (c.azimuthDeg case final az?)
                            Polyline<Object>(
                              points: _sectorLine(s, az),
                              color: scheme.primary,
                              strokeWidth: 3,
                            ),
                      if (selected != null && selectedSite != null)
                        Polyline<Object>(
                          points: [_latLng(selected), _sitePoint(selectedSite)],
                          color: scheme.tertiary,
                          strokeWidth: 3,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final s in sites)
                        Marker(
                          point: _sitePoint(s),
                          width: 28,
                          height: 28,
                          child: Tooltip(
                            message:
                                '${s.label} (estimated, ±${s.uncertaintyM.round()} m)',
                            child: Icon(
                              Icons.cell_tower,
                              color: scheme.primary,
                              semanticLabel: s.label,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (last != null)
                  CircleLayer<Object>(
                    circles: [
                      CircleMarker<Object>(
                        point: _latLng(last),
                        radius: 7,
                        color: Colors.white,
                        borderColor: trackColor(last.quality),
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                if (config.enabled)
                  SimpleAttributionWidget(source: Text(config.attribution)),
              ],
            ),
            if (sites.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: FilterChip(
                  label: const Text('Serving lines'),
                  selected: _servingLines,
                  onSelected: (on) => setState(() => _servingLines = on),
                ),
              ),
            if (selected != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 24,
                child: Card(
                  child: ListTile(
                    dense: true,
                    title: Text(
                      selectedSite == null
                          ? 'Serving cell not located'
                          : 'Serving: ${selectedSite.label}',
                    ),
                    subtitle: Text(
                      [
                        if (selected.levelDbm case final l?)
                          '${l.toStringAsFixed(0)} dBm',
                        if (selectedSite != null)
                          '${const Distance().as(LengthUnit.Meter, _latLng(selected), _sitePoint(selectedSite)).round()} m to estimated site',
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selected = null),
                    ),
                  ),
                ),
              ),
            if (last == null && sites.isEmpty)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Waiting for a GPS fix'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Colour key for the track; every colour is paired with its label.
class TrackLegend extends StatelessWidget {
  const TrackLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final q in SignalQuality.values)
            item(signalQualityColor(q), q.label),
          item(unknownLevelColor, 'No level'),
          Text('RSRP (4G/5G), RSCP (3G), RSSI (2G)', style: style),
        ],
      ),
    );
  }
}
