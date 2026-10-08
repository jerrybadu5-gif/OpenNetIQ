import 'package:opennetiq_mobile/data/mappers/location_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/location_repository.dart';

Map<String, Object?> fixPayload({bool mock = false, double hAcc = 4.2}) =>
    <String, Object?>{
      'fix_time': '2026-10-08T00:59:59.500Z',
      'lat': -9.4438,
      'lon': 147.1803,
      'altitude_m': 35.0,
      'speed_mps': 13.9,
      'bearing_deg': 271.8,
      'h_accuracy_m': hAcc,
      'v_accuracy_m': 7.0,
      'provider': 'gps',
      'is_mock': mock,
    };

Map<String, Object?> locationPayload({
  bool providerEnabled = true,
  String quality = 'GOOD',
  Map<String, Object?>? fix,
  bool withFix = true,
  int? satellitesUsed = 9,
  int? satellitesVisible = 14,
}) => <String, Object?>{
  'timestamp': '2026-10-08T01:00:00.000Z',
  'provider_enabled': providerEnabled,
  'gps_quality': quality,
  'fix_age_ms': withFix ? 800 : null,
  'satellites_used': satellitesUsed,
  'satellites_visible': satellitesVisible,
  'fix': withFix ? (fix ?? fixPayload()) : null,
};

LocationStatus locationStatus({
  bool providerEnabled = true,
  String quality = 'GOOD',
  bool withFix = true,
  bool mock = false,
  int? satellitesVisible = 14,
}) => LocationMapper.fromChannel(
  locationPayload(
    providerEnabled: providerEnabled,
    quality: quality,
    withFix: withFix,
    fix: fixPayload(mock: mock),
    satellitesVisible: satellitesVisible,
  ),
);

class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository({this.statuses = const [], this.error});

  final List<LocationStatus> statuses;
  final LocationException? error;
  int watchCount = 0;

  @override
  Stream<LocationStatus> watchLocation({
    Duration interval = const Duration(seconds: 1),
  }) {
    watchCount++;
    final e = error;
    if (e != null) return Stream<LocationStatus>.error(e);
    return Stream<LocationStatus>.fromIterable(statuses);
  }
}
