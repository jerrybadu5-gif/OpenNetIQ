import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/repositories/recording_service.dart';
import 'package:opennetiq_mobile/features/recording/application/live_track.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';
import '../fixtures/recording_fixtures.dart';
import '../fixtures/session_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeRecordingService service;
  late FakeClock clock;

  ProviderContainer makeContainer({
    FakeDeviceInfoSource? device,
    FakeRecordingService? recordingService,
  }) {
    service = recordingService ?? FakeRecordingService();
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceInfoSourceProvider.overrideWithValue(
          device ?? FakeDeviceInfoSource(),
        ),
        recordingServiceProvider.overrideWithValue(service),
        clockProvider.overrideWithValue(clock.call),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = memoryDatabase();
    clock = FakeClock();
    container = makeContainer();
  });
  tearDown(() => db.close());

  RecordingController controller() =>
      container.read(recordingControllerProvider.notifier);
  RecordingState state() => container.read(recordingControllerProvider);

  Future<void> settle() => pumpEventQueue();

  test('records ticks into a new session and completes it', () async {
    await controller().start();
    expect(state().phase, RecordingPhase.recording);
    final sessionId = state().sessionId!;
    expect(service.calls, ['stop', 'start']); // recovery, then start
    expect(service.lastTitle, startsWith('Recording Session '));

    for (var s = 0; s < 3; s++) {
      clock.advance(const Duration(seconds: 1));
      controller().onSnapshot(
        snapshotAt(s),
        s.isEven ? locationStatus() : null,
      );
    }
    await controller().stop();

    final track = container.read(liveTrackProvider);
    expect(track, hasLength(3));
    expect(track.where((p) => p.hasPosition), hasLength(2));

    final after = state();
    expect(after.phase, RecordingPhase.idle);
    expect(after.lastSessionId, sessionId);
    expect(after.recordedSamples, 3);
    expect(after.failedSamples, 0);
    expect(after.lastReport!.recorded, 3);
    expect(after.lastReport!.missing, 0);
    expect(service.calls.last, 'stop');
    expect(service.hasListener, isFalse);

    final session = await container
        .read(sessionRepositoryProvider)
        .getSession(sessionId);
    expect(session!.status, SessionStatus.completed);
    expect(session.sampleCount, 3);
    expect(session.type, SessionType.drive);
    expect(session.samplingIntervalMs, 1000);
    expect(await db.select(db.devices).get(), hasLength(1));
  });

  test('a new session starts with an empty live track', () async {
    await controller().start();
    controller().onSnapshot(snapshotAt(0), null);
    await controller().stop();
    expect(container.read(liveTrackProvider), hasLength(1));

    await controller().start();
    expect(container.read(liveTrackProvider), isEmpty);
  });

  test('uses the chosen name, type, interval and operator', () async {
    await controller().start(
      const RecordingOptions(
        type: SessionType.walk,
        interval: Duration(seconds: 5),
        name: '  Port Moresby CBD  ',
        operatorUnderTest: ' bmobile ',
      ),
    );
    expect(container.read(radioIntervalProvider), const Duration(seconds: 5));
    final session = await container
        .read(sessionRepositoryProvider)
        .getSession(state().sessionId!);
    expect(session!.name, 'Port Moresby CBD');
    expect(session.type, SessionType.walk);
    expect(session.samplingIntervalMs, 5000);
    expect(session.operatorUnderTest, 'bmobile');

    await controller().stop();
    expect(container.read(radioIntervalProvider), const Duration(seconds: 1));
  });

  test('blank operator is stored as null', () async {
    await controller().start(const RecordingOptions(operatorUnderTest: ' '));
    final session = await container
        .read(sessionRepositoryProvider)
        .getSession(state().sessionId!);
    expect(session!.operatorUnderTest, isNull);
  });

  test('rejects intervals outside the methodology', () async {
    await controller().start(
      const RecordingOptions(interval: Duration(seconds: 3)),
    );
    expect(state().phase, RecordingPhase.idle);
    expect(state().error, contains('Unsupported sampling interval'));
    expect(await db.select(db.sessions).get(), isEmpty);
  });

  test('pause excludes time and ticks, resume continues', () async {
    await controller().start();
    final sessionId = state().sessionId!;
    controller().onSnapshot(snapshotAt(0), null);
    clock.advance(const Duration(seconds: 10));
    controller().onSnapshot(snapshotAt(10), null);
    await settle();

    await controller().pause();
    expect(state().phase, RecordingPhase.paused);
    expect(
      (await container.read(sessionRepositoryProvider).getSession(sessionId))!
          .status,
      SessionStatus.paused,
    );
    clock.advance(const Duration(minutes: 5));
    controller().onSnapshot(snapshotAt(100), null);
    expect(state().activeDuration(clock.now), const Duration(seconds: 10));
    expect(service.updates.last, startsWith('Paused'));

    await controller().resume();
    expect(state().phase, RecordingPhase.recording);
    expect(
      (await container.read(sessionRepositoryProvider).getSession(sessionId))!
          .status,
      SessionStatus.recording,
    );
    clock.advance(const Duration(seconds: 2));
    expect(state().activeDuration(clock.now), const Duration(seconds: 12));
    controller().onSnapshot(snapshotAt(312), null);
    await controller().stop();

    expect(state().recordedSamples, 3);
    expect(state().activeBefore, const Duration(seconds: 12));
    // 0 -> 10 s misses 9 ticks; 10 -> 312 s spans the 300 s pause, so only
    // 2 active seconds (1 missing tick) count.
    final report = state().lastReport!;
    expect(report.gaps.map((g) => g.missing), [9, 1]);
    expect(report.missing, 10);
  });

  test('pause/resume are ignored in the wrong phase', () async {
    await controller().pause();
    await controller().resume();
    expect(state().phase, RecordingPhase.idle);

    await controller().start();
    await controller().resume();
    expect(state().phase, RecordingPhase.recording);
  });

  test('live completeness follows recorded vs expected ticks', () async {
    await controller().start();
    for (var s = 0; s < 8; s++) {
      controller().onSnapshot(snapshotAt(s), null);
    }
    await settle();
    clock.advance(const Duration(seconds: 10));
    expect(state().liveCompleteness(clock.now), closeTo(0.8, 1e-9));
  });

  test('notification updates are throttled', () async {
    await controller().start();
    for (var s = 0; s < 12; s++) {
      clock.advance(const Duration(seconds: 1));
      controller().onSnapshot(snapshotAt(s), locationStatus());
      await settle();
    }
    // Updates at +5 s and +10 s only.
    expect(service.updates, hasLength(2));
    expect(service.updates.first, contains('samples'));
    expect(service.updates.first, contains('RSRP -95 dBm'));
    expect(service.updates.first, contains('GPS'));
  });

  test('notification text without a serving cell or location', () {
    final text = RecordingController.notificationText(
      3,
      snapshot(cells: const []),
      null,
    );
    expect(text, contains('3 samples'));
    expect(text, contains('GPS n/a'));
    expect(text, isNot(contains('dBm')));
  });

  test('stop request from the notification ends the session', () async {
    await controller().start();
    service.emit(const RecordingStopRequested());
    await settle();
    expect(state().phase, RecordingPhase.idle);
    expect(state().lastSessionId, isNotNull);
  });

  test('service failure keeps recording in the foreground', () async {
    container = makeContainer(
      recordingService: FakeRecordingService(startError: 'not visible'),
    );
    await controller().start();
    expect(state().phase, RecordingPhase.recording);
    expect(state().backgroundAvailable, isFalse);
    expect(state().error, contains('Background recording unavailable'));

    controller().onSnapshot(snapshotAt(0), null);
    await settle();
    expect(service.updates, isEmpty);
    expect(state().recordedSamples, 1);
  });

  test('a service failure event is surfaced', () async {
    await controller().start();
    service.emit(const RecordingServiceFailed('FOREGROUND_DENIED', 'revoked'));
    await settle();
    expect(state().backgroundAvailable, isFalse);
    expect(state().error, contains('revoked'));
  });

  test('ignores ticks while idle and double start/stop', () async {
    controller().onSnapshot(snapshot(), null);
    await controller().stop();
    expect(await db.select(db.samples).get(), isEmpty);

    await controller().start();
    await controller().start();
    expect(await db.select(db.sessions).get(), hasLength(1));
  });

  test('start runs crash recovery first', () async {
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

    await controller().start();

    expect(
      (await sessions.getSession(orphan.id))!.status,
      SessionStatus.aborted,
    );
    expect(
      (await sessions.getSession(state().sessionId!))!.status,
      SessionStatus.recording,
    );
  });

  test('reports start failures instead of failing silently', () async {
    container = makeContainer(device: FakeDeviceInfoSource(error: 'no bridge'));
    await controller().start();

    expect(state().phase, RecordingPhase.idle);
    expect(state().error, contains('no bridge'));
    expect(service.calls, ['stop']); // recovery only
  });

  test('counts samples that could not be stored', () async {
    await controller().start();
    final sessionId = state().sessionId!;
    await container.read(sessionRepositoryProvider).deleteSession(sessionId);

    controller().onSnapshot(snapshot(), null);
    await controller().stop();

    expect(state().failedSamples, 1);
    expect(state().error, isNotNull);
  });

  test('default session name uses local date and time', () {
    expect(
      RecordingController.defaultName(DateTime(2026, 10, 8, 9, 5)),
      'Session 2026-10-08 09:05',
    );
  });

  test('startup recovery never fails', () async {
    final c = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(_FailingSessions()),
        recordingServiceProvider.overrideWithValue(FakeRecordingService()),
      ],
    );
    addTearDown(c.dispose);
    expect(await c.read(startupRecoveryProvider.future), 0);
  });
}

class _FailingSessions extends FakeSessionRepository {
  _FailingSessions() : super(const []);

  @override
  Future<int> abortOrphanedSessions() async => throw StateError('db closed');
}
