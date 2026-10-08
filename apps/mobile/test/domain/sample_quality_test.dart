import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/location_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/services/sample_quality.dart';

import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';

LocationStatus statusAt(String timestamp, {String quality = 'GOOD'}) =>
    LocationMapper.fromChannel(
      locationPayload(quality: quality)..['timestamp'] = timestamp,
    );

void main() {
  test('haversine: 0.001 degree of latitude is about 111 m', () {
    expect(
      SampleQuality.haversineM(-9.44, 147.18, -9.441, 147.18),
      closeTo(111.195, 0.01),
    );
    expect(SampleQuality.haversineM(0, 0, 0, 0), 0);
  });

  test('usable fix requires a fix, quality and matching time', () {
    final radio = snapshot();
    expect(SampleQuality.usableFix(radio, null), isNull);
    expect(
      SampleQuality.usableFix(radio, statusAt('2026-10-08T01:00:01.500Z')),
      isNotNull,
    );
    expect(
      SampleQuality.usableFix(radio, statusAt('2026-10-08T01:00:02.500Z')),
      isNull,
    );
    expect(
      SampleQuality.usableFix(
        radio,
        statusAt('2026-10-08T01:00:00.000Z', quality: 'NONE'),
      ),
      isNull,
    );
    expect(
      SampleQuality.usableFix(radio, locationStatus(withFix: false)),
      isNull,
    );
  });

  test('flags merge, sort and de-duplicate', () {
    final fix = locationStatus().fix!;
    final mockFix = locationStatus(mock: true).fix!;
    expect(SampleQuality.mergeFlags(snapshot(), fix), isNull);
    expect(SampleQuality.mergeFlags(snapshot(), null), 'NO_GPS_FIX');
    expect(
      SampleQuality.mergeFlags(snapshot(qualityFlag: 'STALE|CACHED'), mockFix),
      'CACHED|MOCK_LOCATION|STALE',
    );
  });

  test('distance eligibility and glitch filter', () {
    final good = locationStatus();
    final poor = locationStatus(quality: 'POOR');
    final mock = locationStatus(mock: true);
    expect(SampleQuality.countsForDistance(good, good.fix), isTrue);
    expect(SampleQuality.countsForDistance(poor, poor.fix), isFalse);
    expect(SampleQuality.countsForDistance(mock, mock.fix), isFalse);
    expect(SampleQuality.countsForDistance(good, null), isFalse);

    final a = good.fix!;
    expect(SampleQuality.stepM(null, a), 0);
    expect(SampleQuality.stepM(a, a), 0);
  });
}
