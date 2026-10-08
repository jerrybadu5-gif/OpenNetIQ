import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_history.dart';

import '../fixtures/radio_fixtures.dart';

void main() {
  SignalPoint point(int second, [double? level]) => SignalPoint(
    time: DateTime.utc(2026, 10, 8, 0, 0, second),
    levelDbm: level,
  );

  test('appends in order', () {
    var history = <SignalPoint>[];
    history = appendPoint(history, point(1, -90));
    history = appendPoint(history, point(2));
    expect(history.map((p) => p.levelDbm), [-90, null]);
  });

  test('keeps only the most recent capacity points', () {
    var history = <SignalPoint>[];
    for (var i = 0; i < 70; i++) {
      history = appendPoint(history, point(i % 60, -100.0 + i));
    }
    expect(history, hasLength(signalHistoryCapacity));
    expect(history.first.levelDbm, -90);
    expect(history.last.levelDbm, -31);
  });

  test('respects a custom capacity and returns an unmodifiable list', () {
    final history = appendPoint([point(1), point(2)], point(3), capacity: 2);
    expect(history.map((p) => p.time.second), [2, 3]);
    expect(() => history.add(point(4)), throwsUnsupportedError);
  });

  test('point from snapshot uses the primary cell level', () {
    final p = SignalPoint.fromSnapshot(snapshot());
    expect(p.levelDbm, -95);
    expect(p.rat, Rat.lte);
    expect(p.time, DateTime.utc(2026, 10, 8, 1));

    final empty = SignalPoint.fromSnapshot(
      snapshot(cells: [lteCell(serving: false)]),
    );
    expect(empty.levelDbm, isNull);
    expect(empty.rat, isNull);
  });
}
