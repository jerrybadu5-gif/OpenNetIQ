/// GNSS fix quality (`samples.gps_quality`, MEASUREMENT-METHODOLOGY.md section 1):
/// GOOD = fix age <= 2 s and horizontal accuracy <= 50 m.
enum GpsQuality {
  good('GOOD', 'Good'),
  poor('POOR', 'Poor'),
  none('NONE', 'No fix');

  const GpsQuality(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static GpsQuality? fromWire(String? value) {
    for (final q in values) {
      if (q.wireValue == value) return q;
    }
    return null;
  }
}

/// One validated GNSS fix from the AOSP GPS provider (ADR-006).
class LocationFix {
  const LocationFix({
    required this.fixTime,
    required this.lat,
    required this.lon,
    required this.provider,
    required this.isMock,
    this.altitudeM,
    this.speedMps,
    this.bearingDeg,
    this.hAccuracyM,
    this.vAccuracyM,
  });

  final DateTime fixTime;
  final double lat;
  final double lon;
  final double? altitudeM;
  final double? speedMps;
  final double? bearingDeg;
  final double? hAccuracyM;
  final double? vAccuracyM;
  final String provider;

  /// True when Android reports a mock-location provider; such samples are
  /// flagged `MOCK_LOCATION` and excluded from regulatory statistics.
  final bool isMock;

  double? get speedKmh => speedMps == null ? null : speedMps! * 3.6;
}

/// Location state at one sampling tick.
class LocationStatus {
  const LocationStatus({
    required this.timestamp,
    required this.providerEnabled,
    required this.quality,
    this.fixAgeMs,
    this.satellitesUsed,
    this.satellitesVisible,
    this.fix,
  });

  final DateTime timestamp;

  /// False when the user has switched off Location / GPS in Android.
  final bool providerEnabled;
  final GpsQuality quality;
  final int? fixAgeMs;
  final int? satellitesUsed;
  final int? satellitesVisible;
  final LocationFix? fix;

  bool get hasFix => fix != null;
}
