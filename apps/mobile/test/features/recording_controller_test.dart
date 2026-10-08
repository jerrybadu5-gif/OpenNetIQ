import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  ProviderContainer makeContainer({FakeDeviceInfoSource? device}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceInfoSourceProvider.overrideWithValue(
          device ?? FakeDeviceInfoSource(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = memoryDatabase();
    container = makeContainer();
  });
  tearDown(() => db.close());

  RecordingController controller() =>
      container.read(recordingControllerProvider.notifier);

  test('records ticks into a new session and completes it', () async {
    await controller().start();
    final state = container.read(recordingControllerProvider);
    expect(state.phase, RecordingPhase.recording);
    final sessionId = state.sessionId!;

    controller()
      ..onSnapshot(snapshot(), locationStatus())
      ..onSnapshot(snapshot(), null)
      ..onSnapshot(snapshot(), locationStatus());
    await controller().stop();

    final after = container.read(recordingControllerProvider);
    expect(after.phase, RecordingPhase.idle);
    expect(after.lastSessionId, sessionId);
    expect(after.failedSamples, 0);

    final session = await container
        .read(sessionRepositoryProvider)
        .getSession(sessionId);
    expect(session!.status, SessionStatus.completed);
    expect(session.sampleCount, 3);
    expect(session.type, SessionType.drive);
    expect(session.samplingIntervalMs, 1000);
    expect(session.name, startsWith('Session '));
    expect(await db.select(db.devices).get(), hasLength(1));
  });

  test('ignores ticks while idle and double start/stop', () async {
    controller().onSnapshot(snapshot(), null);
    await controller().stop();
    expect(await db.select(db.samples).get(), isEmpty);

    await controller().start();
    await controller().start();
    expect(await db.select(db.sessions).get(), hasLength(1));
  });

  test('reports start failures instead of failing silently', () async {
    container = makeContainer(device: FakeDeviceInfoSource(error: 'no bridge'));
    await controller().start();

    final state = container.read(recordingControllerProvider);
    expect(state.phase, RecordingPhase.idle);
    expect(state.error, contains('no bridge'));
  });

  test('counts samples that could not be stored', () async {
    await controller().start();
    final sessionId = container.read(recordingControllerProvider).sessionId!;
    await container.read(sessionRepositoryProvider).deleteSession(sessionId);

    controller().onSnapshot(snapshot(), null);
    await controller().stop();

    final state = container.read(recordingControllerProvider);
    expect(state.failedSamples, 1);
    expect(state.error, contains('Sample not stored'));
  });

  test('default session name uses local date and time', () {
    expect(
      RecordingController.defaultName(DateTime(2026, 10, 8, 9, 5)),
      'Session 2026-10-08 09:05',
    );
  });
}
