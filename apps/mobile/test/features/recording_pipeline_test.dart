import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_pipeline.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';
import '../fixtures/recording_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ControlledRadioRepository radio;
  late FakeLocationRepository location;

  setUp(() {
    db = memoryDatabase();
    radio = ControlledRadioRepository();
    location = FakeLocationRepository(statuses: [locationStatus()]);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceInfoSourceProvider.overrideWithValue(FakeDeviceInfoSource()),
        recordingServiceProvider.overrideWithValue(FakeRecordingService()),
        clockProvider.overrideWithValue(FakeClock().call),
        radioRepositoryProvider.overrideWithValue(radio),
        locationRepositoryProvider.overrideWithValue(location),
      ],
    );
    startRecordingRuntime(container);
  });
  tearDown(() async {
    container.dispose();
    await radio.controller.close();
    await db.close();
  });

  RecordingController controller() =>
      container.read(recordingControllerProvider.notifier);

  Future<void> tick(int second) async {
    radio.controller.add(snapshotAt(second));
    await pumpEventQueue();
  }

  test('no radio or GPS subscription while idle', () async {
    await pumpEventQueue();
    expect(radio.intervals, isEmpty);
    expect(location.watchCount, 0);
  });

  test('stores every tick while recording, without any screen', () async {
    await controller().start(
      const RecordingOptions(interval: Duration(seconds: 2)),
    );
    await pumpEventQueue();
    expect(radio.intervals, [const Duration(seconds: 2)]);
    expect(location.watchCount, 1);

    await tick(0);
    await tick(2);
    await tick(4);
    final sessionId = container.read(recordingControllerProvider).sessionId!;
    await controller().stop();

    final session = await container
        .read(sessionRepositoryProvider)
        .getSession(sessionId);
    expect(session!.sampleCount, 3);
    final samples = await db.select(db.samples).get();
    expect(samples.where((s) => s.lat != null), isNotEmpty);
  });

  test('paused ticks are not stored', () async {
    await controller().start();
    await pumpEventQueue();
    await tick(0);
    await controller().pause();
    await tick(1);
    await tick(2);
    await controller().resume();
    await tick(3);
    expect(container.read(recordingControllerProvider).recordedSamples, 2);
  });

  test('runtime aborts sessions orphaned by a killed process', () async {
    await container.read(startupRecoveryProvider.future);
    final sessions = container.read(sessionRepositoryProvider);
    final deviceId = await container
        .read(deviceRegistryProvider)
        .ensureDevice(testDevice);
    final orphan = await sessions.createSession(
      deviceId: deviceId,
      name: 'Killed',
      type: SessionType.drive,
      samplingIntervalMs: 1000,
    );
    await sessions.startRecording(orphan.id);

    // A new process: fresh container, recovery runs at startup.
    final next = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        recordingServiceProvider.overrideWithValue(FakeRecordingService()),
      ],
    );
    addTearDown(next.dispose);
    startRecordingRuntime(next);
    expect(await next.read(startupRecoveryProvider.future), 1);
    expect(
      (await sessions.getSession(orphan.id))!.status,
      SessionStatus.aborted,
    );
  });
}
