import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/features/latency_test/application/latency_test_controller.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/latency_fixtures.dart';
import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';
import '../fixtures/recording_fixtures.dart';

class _Started {
  const _Started(this.run);

  final Future<void> run;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeLatencyEngine engine;
  late ControlledRadioRepository radio;

  setUp(() {
    db = memoryDatabase();
    engine = FakeLatencyEngine();
    radio = ControlledRadioRepository();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceInfoSourceProvider.overrideWithValue(FakeDeviceInfoSource()),
        recordingServiceProvider.overrideWithValue(FakeRecordingService()),
        latencyEngineProvider.overrideWithValue(engine),
        testRadioWaitProvider.overrideWithValue(const Duration(seconds: 1)),
        radioRepositoryProvider.overrideWithValue(radio),
        locationRepositoryProvider.overrideWithValue(
          FakeLocationRepository(statuses: [locationStatus()]),
        ),
      ],
    )..listen<void>(latencyTestPipelineProvider, (previous, next) {});
  });
  tearDown(() async {
    container.dispose();
    await radio.controller.close();
    await db.close();
  });

  LatencyTestController controller() =>
      container.read(latencyTestControllerProvider.notifier);
  LatencyTestState state() => container.read(latencyTestControllerProvider);

  Future<_Started> begin({
    String server = 'https://speed.example.org:8443/backend/',
  }) async {
    await container
        .read(settingsRepositoryProvider)
        .setSetting(speedTestServerKey, server);
    container.invalidate(speedTestServerProvider);
    final run = controller().start();
    for (var i = 0; i < 500 && !engine.running; i++) {
      radio.controller.add(snapshot());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(engine.running, isTrue);
    return _Started(run);
  }

  test('needs a test server', () async {
    await controller().start();
    expect(state().error, contains('test server'));
    expect(engine.configs, isEmpty);
  });

  test(
    'probes the server host and port, stores one row per protocol',
    () async {
      final run = (await begin()).run;
      final config = engine.configs.single;
      expect(config.host, 'speed.example.org');
      expect(config.port, 8443);
      expect(config.protocols, LatencyProtocol.values);
      expect(config.probes, 20);
      expect(state().target, 'speed.example.org:8443');

      engine
        ..emit(const LatencyProtocolStarted(LatencyProtocol.icmp))
        ..emit(const LatencyProbe(LatencyProtocol.icmp, 1, 21.0))
        ..emit(const LatencyProbe(LatencyProtocol.icmp, 2, null));
      await pumpEventQueue();
      expect(state().protocol, LatencyProtocol.icmp);
      expect(state().probes, hasLength(2));

      engine
        ..emit(LatencyCompleted(latencyResult(protocol: LatencyProtocol.icmp)))
        ..emit(const LatencyProtocolStarted(LatencyProtocol.tcp));
      await pumpEventQueue();
      expect(state().probes, isEmpty); // reset per protocol
      expect(state().results, hasLength(1));

      engine.emit(LatencyCompleted(latencyResult()));
      await engine.finish();
      await run;

      expect(state().running, isFalse);
      expect(state().results.map((r) => r.protocol), [
        LatencyProtocol.icmp,
        LatencyProtocol.tcp,
      ]);
      expect(state().error, isNull);

      final rows = await db.select(db.latencyTests).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.sessionId).toSet(), hasLength(1));
      expect(rows.first.measurementId, isNotNull);
      expect(rows.first.methodologyVersion, '1.0.0');
      final session = await container
          .read(sessionRepositoryProvider)
          .getSession(rows.first.sessionId!);
      expect(session!.type, SessionType.singleTest);
      expect(session.name, startsWith('Latency test '));
    },
  );

  test('cancel stores nothing', () async {
    final run = (await begin()).run;
    await controller().cancel();
    await run;
    expect(engine.cancelled, isTrue);
    expect(state().running, isFalse);
    expect(await db.select(db.latencyTests).get(), isEmpty);
  });

  test('engine errors are reported, nothing stored', () async {
    final run = (await begin()).run;
    engine.fail(StateError('INVALID_CONFIG'));
    await run;
    expect(state().error, contains('INVALID_CONFIG'));
    expect(await db.select(db.latencyTests).get(), isEmpty);
  });

  test('a run without results is an error', () async {
    final run = (await begin()).run;
    await engine.finish();
    await run;
    expect(state().error, contains('without results'));
    expect(await db.select(db.latencyTests).get(), isEmpty);
  });
}
