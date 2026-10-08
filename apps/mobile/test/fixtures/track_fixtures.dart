import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';

/// Track start for [pt].
final t0 = DateTime.utc(2026, 10, 8, 1);

/// Sample [second]s after [t0], moving north ~11 m per second.
SamplePoint pt(
  int second, {
  double? level = -85,
  Rat? rat = Rat.lte,
  bool positioned = true,
  bool mock = false,
  NetworkType? networkType = NetworkType.lte,
}) => SamplePoint(
  timestamp: t0.add(Duration(seconds: second)),
  networkType: networkType,
  lat: positioned ? -9.44 + second * 1e-4 : null,
  lon: positioned ? 147.18 : null,
  mockLocation: mock,
  gpsQuality: positioned ? GpsQuality.good : GpsQuality.none,
  rat: rat,
  levelDbm: level,
);
