import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
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
    super.key,
  });

  final List<SamplePoint> points;
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

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mapTileConfigProvider);
    final segments = _segmentsFor(widget.points);
    final last = _last;
    final positioned = [
      for (final p in widget.points)
        if (p.hasPosition) _latLng(p),
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
            if (last == null)
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
