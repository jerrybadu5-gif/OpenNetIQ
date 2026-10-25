import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

import '../fixtures/radio_fixtures.dart';

void main() {
  test('level tracker averages dBm and keeps the first RAT', () {
    var closed = 0;
    final t = LevelTracker(() => closed++)
      ..add(-90, 'LTE')
      ..add(-101, 'WCDMA');
    final r = t.finish();
    expect(r.meanDbm, -95.5);
    expect(r.rat, 'LTE');
    expect(closed, 1);
    expect(LevelTracker(() {}).finish().meanDbm, isNull);
  });

  test('test context tracks the serving level from radio snapshots', () async {
    final c = ProviderContainer(
      overrides: [
        radioSnapshotProvider.overrideWith(
          (ref) => Stream.fromIterable([
            snapshot(),
            snapshot(cells: [lteCell(rsrp: -105)]),
          ]),
        ),
      ],
    );
    addTearDown(c.dispose);
    final tracker = c.read(testContextProvider).trackServingLevel();
    await pumpEventQueue();
    final r = tracker.finish();
    expect(r.meanDbm, -100.0); // (-95 + -105) / 2
    expect(r.rat, 'LTE');
  });
}
