import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';
import '../fixtures/recording_fixtures.dart';
import '../fixtures/speed_fixtures.dart';

const server = 'https://speed.example.org/backend/';

class _StartedSpeedTest {
  const _StartedSpeedTest(this.run);

  final Future<void> run;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeSpeedTestEngine engine;
  late ControlledRadioRepository radio;

  ProviderContainer make({bool permitted = true}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceInfoSourceProvider.overrideWithValue(FakeDeviceInfoSource()),
        recordingServiceProvider.overrideWithValue(FakeRecordingService()),
        speedTestEngineProvider.overrideWithValue(engine),
        speedTestRadioWaitProvider.overrideWithValue(
          const Duration(seconds: 1),
        ),
        radioRepositoryProvider.overrideWithValue(
          permitted
              ? radio
              : FakeRadioRepository(permissions: deniedPermissions),
        ),
        locationRepositoryProvider.overrideWithValue(
          FakeLocationRepository(statuses: [locationStatus()]),
        ),
      ],
    );
    c.listen<void>(speedTestPipelineProvider, (previous, next) {});
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = memoryDatabase();
    engine = FakeSpeedTestEngine();
    radio = ControlledRadioRepository();
    container = make();
  });
  tearDown(() async {
    await radio.controller.close();
    await db.close();
  });

  SpeedTestController controller() =>
      container.read(speedTestControllerProvider.notifier);
  SpeedTestState state() => container.read(speedTestControllerProvider);

  /// Starts a test and waits until the engine is running.
  Future<_StartedSpeedTest> begin() async {
    await controller().saveServer(server);
    final run = controller().start();
    for (var i = 0; i < 500 && !engine.running; i++) {
      radio.controller.add(snapshot());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(engine.running, isTrue);
    return _StartedSpeedTest(run);
  }

  test('refuses to start without a server', () async {
    await controller().start();
    expect(state().error, contains('server'));
    expect(engine.configs, isEmpty);
  });

  test('saved server is used and trimmed', () async {
    await controller().saveServer('  $server ');
    expect(await container.read(speedTestServerProvider.future), server);
  });

  test('runs, tracks progress and stores the result with a snapshot', () async {
    final run = (await begin()).run;
    expect(state().running, isTrue);
    expect(engine.configs.single.serverUrl, server);
    expect(engine.configs.single.streams, 4);

    engine
      ..emit(const SpeedTestPhaseChanged(SpeedTestPhase.download))
      ..emit(
        const SpeedTestProgress(
          SpeedTestPhase.download,
          Duration(milliseconds: 100),
          40,
        ),
      );
    await pumpEventQueue();
    expect(state().phase, SpeedTestPhase.download);
    expect(state().liveMbps, 40);

    engine.emit(
      const SpeedTestProgress(
        SpeedTestPhase.upload,
        Duration(milliseconds: 100),
        10,
      ),
    );
    await engine.finish(okResult);
    await run;

    final s = state();
    expect(s.running, isFalse);
    expect(s.result!.status, SpeedTestStatus.ok);
    expect(s.downloadCurve, hasLength(1));
    expect(s.uploadCurve, hasLength(1));
    expect(s.ratChanged, isFalse);
    expect(s.error, isNull);

    final record =
        (await container.read(speedTestStoreProvider).watchSpeedTests().first)
            .single;
    expect(record.methodologyVersion, '1.0.0');
    expect(record.serverId, server);
    expect(record.measurementId, isNotNull);
    final session = await container
        .read(sessionRepositoryProvider)
        .getSession(record.sessionId!);
    expect(session!.type, SessionType.singleTest);
    expect(session.status, SessionStatus.completed);
    expect(session.sampleCount, 1);
    expect(session.name, startsWith('Speed test '));
  });

  test('flags a network type change during the test', () async {
    final run = (await begin()).run;
    radio.controller.add(
      snapshot(networkType: 'NR_SA', cells: [nrCell(serving: true)]),
    );
    await pumpEventQueue();
    engine.emit(const SpeedTestPhaseChanged(SpeedTestPhase.upload));
    await engine.finish(okResult);
    await run;
    expect(state().ratChanged, isTrue);
    final record =
        (await container.read(speedTestStoreProvider).watchSpeedTests().first)
            .single;
    expect(record.ratChanged, isTrue);
  });

  test('cancel stops the engine and stores nothing', () async {
    final run = (await begin()).run;
    await controller().cancel();
    await run;
    expect(engine.cancelled, isTrue);
    expect(state().running, isFalse);
    expect(state().result, isNull);
    expect(await db.select(db.speedTests).get(), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
  });

  test('engine errors are reported, nothing stored', () async {
    final run = (await begin()).run;
    engine.fail(StateError('INVALID_CONFIG'));
    await run;
    expect(state().error, contains('INVALID_CONFIG'));
    expect(await db.select(db.speedTests).get(), isEmpty);
  });

  test('a stream ending without a result is an error', () async {
    final run = (await begin()).run;
    await engine.finish();
    await run;
    expect(state().error, contains('without a result'));
  });

  test('during a drive the test links to the open session', () async {
    final recording = container.read(recordingControllerProvider.notifier);
    await recording.start();
    final driveId = container.read(recordingControllerProvider).sessionId!;
    recording.onSnapshot(snapshotAt(0), null);
    await pumpEventQueue();

    final run = (await begin()).run;
    await engine.finish(okResult);
    await run;

    final record =
        (await container.read(speedTestStoreProvider).watchSpeedTests().first)
            .single;
    expect(record.sessionId, driveId);
    expect(record.measurementId, isNotNull);
    final sessions = await db.select(db.sessions).get();
    expect(sessions, hasLength(1)); // no single_test session
  });

  test('without radio access the test still runs, unlinked', () async {
    container = make(permitted: false);
    await controller().saveServer(server);
    final run = controller().start();
    for (var i = 0; i < 500 && !engine.running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(engine.running, isTrue);
    await engine.finish(okResult);
    await run;
    final record =
        (await container.read(speedTestStoreProvider).watchSpeedTests().first)
            .single;
    expect(record.sessionId, isNull);
    expect(record.measurementId, isNull);
  });
}
