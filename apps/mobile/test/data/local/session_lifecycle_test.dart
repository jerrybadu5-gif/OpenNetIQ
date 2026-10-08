import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_device_registry.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/radio_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftMeasurementStore store;
  late String deviceId;
  var clock = DateTime.utc(2026, 10, 8, 1);

  setUp(() async {
    db = memoryDatabase();
    clock = DateTime.utc(2026, 10, 8, 1);
    store = DriftMeasurementStore(db, now: () => clock, newId: sequentialIds());
    deviceId = await DriftDeviceRegistry(db).ensureDevice(testDevice);
  });
  tearDown(() => db.close());

  Future<String> newSession() async => (await store.createSession(
    deviceId: deviceId,
    name: 'Route',
    type: SessionType.drive,
    samplingIntervalMs: 1000,
  )).id;

  test('pause and resume keep the first start time', () async {
    final id = await newSession();
    await store.startRecording(id);
    clock = clock.add(const Duration(minutes: 1));
    await store.pauseRecording(id);
    expect((await store.getSession(id))!.status, SessionStatus.paused);

    clock = clock.add(const Duration(minutes: 1));
    await store.startRecording(id);
    final resumed = (await store.getSession(id))!;
    expect(resumed.status, SessionStatus.recording);
    expect(resumed.startedAt, DateTime.utc(2026, 10, 8, 1));
  });

  test('sample timestamps are returned oldest first', () async {
    final id = await newSession();
    await store.startRecording(id);
    for (final s in [2, 0, 1]) {
      await store.recordSample(sessionId: id, radio: snapshotAt(s));
    }
    expect(await store.sampleTimestamps(id), [
      DateTime.utc(2026, 10, 8, 1),
      DateTime.utc(2026, 10, 8, 1, 0, 1),
      DateTime.utc(2026, 10, 8, 1, 0, 2),
    ]);
    expect(await store.sampleTimestamps('unknown'), isEmpty);
  });

  test('orphaned sessions are aborted at their last sample', () async {
    final recording = await newSession();
    await store.startRecording(recording);
    await store.recordSample(sessionId: recording, radio: snapshotAt(0));
    await store.recordSample(sessionId: recording, radio: snapshotAt(42));

    final paused = await newSession();
    await store.startRecording(paused);
    await store.pauseRecording(paused);

    final created = await newSession();

    final done = await newSession();
    await store.startRecording(done);
    await store.finishRecording(done);

    clock = DateTime.utc(2026, 10, 9);
    expect(await store.abortOrphanedSessions(), 3);

    final r = (await store.getSession(recording))!;
    expect(r.status, SessionStatus.aborted);
    expect(r.endedAt, DateTime.utc(2026, 10, 8, 1, 0, 42));
    expect(r.sampleCount, 2);

    final p = (await store.getSession(paused))!;
    expect(p.status, SessionStatus.aborted);
    expect(p.endedAt, DateTime.utc(2026, 10, 8, 1));

    final c = (await store.getSession(created))!;
    expect(c.status, SessionStatus.aborted);
    expect(c.endedAt, DateTime.utc(2026, 10, 8, 1));

    expect((await store.getSession(done))!.status, SessionStatus.completed);
    expect(await store.abortOrphanedSessions(), 0);
  });
}
