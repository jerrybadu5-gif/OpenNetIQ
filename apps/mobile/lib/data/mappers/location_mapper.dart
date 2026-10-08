import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/mappers/channel_reader.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';

/// Maps `org.opennetiq/location` events (snake_case) to [LocationStatus].
abstract final class LocationMapper {
  static LocationStatus fromChannel(Object? event) {
    final r = ChannelReader(event, 'location status');
    final rawFix = r.raw('fix');
    return LocationStatus(
      timestamp: _utc(r.requireString('timestamp'), 'timestamp'),
      providerEnabled: r.requireBool('provider_enabled'),
      quality:
          GpsQuality.fromWire(r.requireString('gps_quality')) ??
          (throw const FormatException('Invalid "gps_quality"')),
      fixAgeMs: r.integer('fix_age_ms'),
      satellitesUsed: r.integer('satellites_used'),
      satellitesVisible: r.integer('satellites_visible'),
      fix: rawFix == null ? null : fixFromChannel(rawFix),
    );
  }

  static LocationFix fixFromChannel(Object? raw) {
    final r = ChannelReader(raw, 'location fix');
    return LocationFix(
      fixTime: _utc(r.requireString('fix_time'), 'fix_time'),
      lat: r.decimal('lat') ?? (throw const FormatException('Missing "lat"')),
      lon: r.decimal('lon') ?? (throw const FormatException('Missing "lon"')),
      altitudeM: r.decimal('altitude_m'),
      speedMps: r.decimal('speed_mps'),
      bearingDeg: r.decimal('bearing_deg'),
      hAccuracyM: r.decimal('h_accuracy_m'),
      vAccuracyM: r.decimal('v_accuracy_m'),
      provider: r.string('provider') ?? 'gps',
      isMock: r.boolean('is_mock') ?? false,
    );
  }

  static DateTime _utc(String value, String key) =>
      parseUtc(value) ??
      (throw FormatException('Invalid "$key": expected UTC ISO 8601'));
}
