import 'dart:math' as math;

import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';

/// Sample-level quality rules (MEASUREMENT-METHODOLOGY.md section 4a).
abstract final class SampleQuality {
  static const String mockLocation = 'MOCK_LOCATION';
  static const String noGpsFix = 'NO_GPS_FIX';

  /// A location status older or newer than this relative to the radio
  /// snapshot is not used to geotag it.
  static const Duration maxRadioLocationSkew = Duration(seconds: 2);

  /// Returns the fix usable for geotagging [radio], or null.
  static LocationFix? usableFix(RadioSnapshot radio, LocationStatus? location) {
    final fix = location?.fix;
    if (location == null || fix == null) return null;
    if (location.quality == GpsQuality.none) return null;
    final skew = radio.timestamp.difference(location.timestamp).abs();
    return skew <= maxRadioLocationSkew ? fix : null;
  }

  /// Snapshot flags plus location flags, sorted and joined with `|`.
  static String? mergeFlags(RadioSnapshot radio, LocationFix? usable) {
    final flags = <String>{
      ...?radio.qualityFlag?.split('|').where((f) => f.isNotEmpty),
      if (usable == null) noGpsFix,
      if (usable?.isMock ?? false) mockLocation,
    };
    if (flags.isEmpty) return null;
    return (flags.toList()..sort()).join('|');
  }

  /// Fix eligible for distance accumulation: GOOD quality and not mocked.
  static bool countsForDistance(
    LocationStatus? location,
    LocationFix? usable,
  ) => usable != null && !usable.isMock && location?.quality == GpsQuality.good;

  /// Larger jumps between consecutive samples are treated as GNSS glitches
  /// and not added to the session distance.
  static const double maxStepM = 500;

  /// Great-circle distance in metres (haversine, mean Earth radius).
  static double haversineM(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371008.8;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(a));
  }

  /// Distance to add between two eligible fixes, or 0 for glitches.
  static double stepM(LocationFix? previous, LocationFix current) {
    if (previous == null) return 0;
    final d = haversineM(previous.lat, previous.lon, current.lat, current.lon);
    return d > maxStepM ? 0 : d;
  }
}
