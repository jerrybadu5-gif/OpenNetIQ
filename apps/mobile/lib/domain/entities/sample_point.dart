import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

/// One stored sample reduced to what maps and session statistics need:
/// position (usable fixes only) and the primary serving cell's level.
class SamplePoint {
  const SamplePoint({
    required this.timestamp,
    this.networkType,
    this.lat,
    this.lon,
    this.mockLocation = false,
    this.gpsQuality,
    this.rat,
    this.levelDbm,
  });

  final DateTime timestamp;
  final NetworkType? networkType;
  final double? lat;
  final double? lon;

  /// Position came from a mock provider: never drawn on maps.
  final bool mockLocation;
  final GpsQuality? gpsQuality;

  /// RAT of the primary serving cell (LTE anchor in 5G NSA).
  final Rat? rat;

  /// RSRP (LTE/NR), RSCP (WCDMA) or RSSI (GSM) of that cell.
  final double? levelDbm;

  bool get hasPosition => lat != null && lon != null && !mockLocation;

  SignalQuality? get quality {
    final r = rat;
    final level = levelDbm;
    return r == null || level == null
        ? null
        : SignalQuality.fromLevel(r, level);
  }
}
