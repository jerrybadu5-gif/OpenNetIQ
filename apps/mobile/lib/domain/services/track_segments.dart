import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/services/sample_quality.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

/// Run of consecutive positioned samples with the same signal class, drawn
/// as one polyline. [quality] is null when no serving-cell level was known.
class TrackSegment {
  const TrackSegment(this.quality, this.points);

  final SignalQuality? quality;
  final List<SamplePoint> points;
}

/// Builds the coloured track (issue #18). Keeps the number of polylines
/// proportional to class changes, not samples, so 10 k points stay smooth.
abstract final class TrackSegments {
  /// Longer time gaps (no samples or no fix) break the line instead of
  /// drawing a straight jump across unmeasured ground.
  static const Duration maxGap = Duration(seconds: 30);

  static List<TrackSegment> build(List<SamplePoint> samples) {
    final segments = <TrackSegment>[];
    List<SamplePoint>? current;
    SignalQuality? currentQuality;
    SamplePoint? previous;
    for (final p in samples) {
      if (!p.hasPosition) continue;
      final q = p.quality;
      final prev = previous;
      final broken =
          prev != null && p.timestamp.difference(prev.timestamp) > maxGap;
      if (current == null || broken) {
        current = [p];
        currentQuality = q;
        segments.add(TrackSegment(q, current));
      } else if (q == currentQuality) {
        current.add(p);
      } else {
        // Close the run at this point so the line stays continuous.
        current.add(p);
        current = [p];
        currentQuality = q;
        segments.add(TrackSegment(q, current));
      }
      previous = p;
    }
    return segments;
  }

  /// Point for a live tick: geotagged only with a fix usable for [radio]
  /// (same rule as stored samples).
  static SamplePoint fromTick(RadioSnapshot radio, LocationStatus? location) {
    final fix = SampleQuality.usableFix(radio, location);
    final cell = radio.primaryCell;
    return SamplePoint(
      timestamp: radio.timestamp,
      networkType: radio.networkType,
      lat: fix?.lat,
      lon: fix?.lon,
      mockLocation: fix?.isMock ?? false,
      gpsQuality: location?.quality,
      rat: cell?.rat,
      levelDbm: cell?.levelDbm,
    );
  }
}
