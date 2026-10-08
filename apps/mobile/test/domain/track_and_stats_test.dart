import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/services/session_stats.dart';
import 'package:opennetiq_mobile/domain/services/track_segments.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';
import '../fixtures/track_fixtures.dart';

void main() {
  group('SamplePoint', () {
    test('quality follows the RAT thresholds', () {
      expect(pt(0, level: -85).quality, SignalQuality.good);
      expect(pt(0, level: -85, rat: Rat.gsm).quality, SignalQuality.fair);
      expect(pt(0, level: null).quality, isNull);
      expect(pt(0, rat: null).quality, isNull);
    });

    test('mock or missing positions are not positioned', () {
      expect(pt(0).hasPosition, isTrue);
      expect(pt(0, mock: true).hasPosition, isFalse);
      expect(pt(0, positioned: false).hasPosition, isFalse);
    });
  });

  group('TrackSegments.build', () {
    test('joins runs of the same class and shares boundary points', () {
      final segments = TrackSegments.build([
        pt(0),
        pt(1),
        pt(2, level: -105),
        pt(3, level: -105),
        pt(4, level: null),
      ]);
      expect(segments.map((s) => s.quality), [
        SignalQuality.good,
        SignalQuality.poor,
        null,
      ]);
      expect(segments[0].points, hasLength(3));
      expect(
        segments[1].points.first.timestamp,
        t0.add(const Duration(seconds: 2)),
      );
      expect(segments[1].points, hasLength(3));
      expect(segments[2].points, hasLength(1));
    });

    test('skips unpositioned samples and breaks on long gaps', () {
      final segments = TrackSegments.build([
        pt(0),
        pt(1, positioned: false),
        pt(2),
        pt(60),
        pt(61),
      ]);
      expect(segments, hasLength(2));
      expect(segments[0].points, hasLength(2));
      expect(segments[1].points, hasLength(2));
    });

    test('empty input', () {
      expect(TrackSegments.build(const []), isEmpty);
    });

    test('10 k points: few segments, fast', () {
      final points = [
        for (var i = 0; i < 10000; i++)
          pt(i, level: i % 1000 < 500 ? -85 : -95),
      ];
      final watch = Stopwatch()..start();
      final segments = TrackSegments.build(points);
      watch.stop();
      expect(segments, hasLength(20));
      expect(watch.elapsedMilliseconds, lessThan(200));
    });

    test('fromTick uses the usable fix and the primary cell', () {
      final p = TrackSegments.fromTick(snapshot(), locationStatus());
      expect(p.hasPosition, isTrue);
      expect(p.rat, Rat.lte);
      expect(p.levelDbm, -95);
      expect(p.networkType, NetworkType.lte);
      expect(p.gpsQuality, GpsQuality.good);

      final noFix = TrackSegments.fromTick(snapshot(), null);
      expect(noFix.hasPosition, isFalse);
      expect(noFix.gpsQuality, isNull);

      final mock = TrackSegments.fromTick(
        snapshot(),
        locationStatus(mock: true),
      );
      expect(mock.hasPosition, isFalse);
      expect(mock.mockLocation, isTrue);

      final noCell = TrackSegments.fromTick(snapshot(cells: const []), null);
      expect(noCell.rat, isNull);
      expect(noCell.levelDbm, isNull);
    });
  });

  group('SessionStats', () {
    test('level statistics per RAT and distributions', () {
      final stats = SessionStats.of([
        pt(0, level: -80),
        pt(1, level: -90),
        pt(2, level: -100),
        pt(3, level: -110),
        pt(4, level: -75, rat: Rat.gsm, networkType: NetworkType.gsm),
        pt(5, level: null, positioned: false, networkType: null),
      ]);
      expect(stats.samples, 6);
      expect(stats.positioned, 5);
      final lte = stats.levelByRat[Rat.lte]!;
      expect(lte.count, 4);
      expect(lte.min, -110);
      expect(lte.max, -80);
      expect(lte.median, -95);
      expect(lte.mean, -95);
      expect(stats.levelByRat[Rat.gsm]!.median, -75);
      expect(stats.qualityCounts[SignalQuality.excellent], 1);
      expect(stats.qualityCounts[SignalQuality.good], 2);
      expect(stats.qualityCounts[SignalQuality.fair], 1);
      expect(stats.qualityCounts[SignalQuality.poor], 1);
      expect(stats.noServiceCell, 1);
      expect(stats.networkCounts[NetworkType.lte], 4);
      expect(stats.networkCounts[NetworkType.gsm], 1);
      expect(stats.share(3), 0.5);
    });

    test('odd median and empty session', () {
      expect(LevelStats.of([-90, -70, -80])!.median, -80);
      expect(LevelStats.of([]), isNull);
      final empty = SessionStats.of(const []);
      expect(empty.samples, 0);
      expect(empty.share(0), 0);
      expect(empty.levelByRat, isEmpty);
    });
  });
}
