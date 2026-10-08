import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/location_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';

import '../fixtures/location_fixtures.dart';

void main() {
  test('maps status and every fix field', () {
    final s = LocationMapper.fromChannel(locationPayload());

    expect(s.timestamp, DateTime.utc(2026, 10, 8, 1));
    expect(s.providerEnabled, isTrue);
    expect(s.quality, GpsQuality.good);
    expect(s.fixAgeMs, 800);
    expect(s.satellitesUsed, 9);
    expect(s.satellitesVisible, 14);
    expect(s.hasFix, isTrue);

    final f = s.fix!;
    expect(f.fixTime, DateTime.utc(2026, 10, 8, 0, 59, 59, 500));
    expect(f.lat, -9.4438);
    expect(f.lon, 147.1803);
    expect(f.altitudeM, 35.0);
    expect(f.speedMps, 13.9);
    expect(f.speedKmh, closeTo(50.04, 0.001));
    expect(f.bearingDeg, 271.8);
    expect(f.hAccuracyM, 4.2);
    expect(f.vAccuracyM, 7.0);
    expect(f.provider, 'gps');
    expect(f.isMock, isFalse);
  });

  test('no fix and optional values', () {
    final s = LocationMapper.fromChannel(
      locationPayload(
        quality: 'NONE',
        withFix: false,
        satellitesUsed: null,
        satellitesVisible: null,
      ),
    );
    expect(s.hasFix, isFalse);
    expect(s.quality, GpsQuality.none);
    expect(s.fixAgeMs, isNull);
    expect(s.satellitesVisible, isNull);
  });

  test('integer coordinates are accepted, optional fix fields default', () {
    final f = LocationMapper.fixFromChannel(<String, Object?>{
      'fix_time': '2026-10-08T00:00:00.000Z',
      'lat': -9,
      'lon': 147,
    });
    expect(f.lat, -9.0);
    expect(f.provider, 'gps');
    expect(f.isMock, isFalse);
    expect(f.speedKmh, isNull);
  });

  test('rejects malformed payloads', () {
    expect(() => LocationMapper.fromChannel(null), throwsFormatException);
    expect(
      () => LocationMapper.fromChannel(
        locationPayload()..['gps_quality'] = 'GREAT',
      ),
      throwsFormatException,
    );
    expect(
      () => LocationMapper.fromChannel(
        locationPayload()..['timestamp'] = '2026-10-08T11:00:00+10:00',
      ),
      throwsFormatException,
    );
    expect(
      () => LocationMapper.fromChannel(
        locationPayload()..remove('provider_enabled'),
      ),
      throwsFormatException,
    );
    expect(
      () => LocationMapper.fromChannel(
        locationPayload(fix: fixPayload()..remove('lat')),
      ),
      throwsFormatException,
    );
    expect(
      () => LocationMapper.fromChannel(
        locationPayload(fix: fixPayload()..['lon'] = 'east'),
      ),
      throwsFormatException,
    );
  });

  test('GpsQuality wire values', () {
    for (final q in GpsQuality.values) {
      expect(GpsQuality.fromWire(q.wireValue), q);
    }
    expect(GpsQuality.fromWire('BAD'), isNull);
    expect(GpsQuality.none.label, 'No fix');
  });
}
