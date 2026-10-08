import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_device_registry.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/data/local/drift_speed_test_store.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/radio_fixtures.dart';
import '../../fixtures/speed_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftSpeedTestStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftSpeedTestStore(db, now: () => DateTime.utc(2026, 10, 9, 1));
  });
  tearDown(() => db.close());

  test('saves every column and reads it back', () async {
    final measurements = DriftMeasurementStore(db, newId: sequentialIds('m'));
    final deviceId = await DriftDeviceRegistry(db).ensureDevice(testDevice);
    final session = await measurements.createSession(
      deviceId: deviceId,
      name: 'Speed test',
      type: SessionType.singleTest,
      samplingIntervalMs: 1000,
    );
    final measurementId = await measurements.recordSample(
      sessionId: session.id,
      radio: snapshot(),
    );

    await store.saveSpeedTest(
      SpeedTestRecord(
        id: 't1',
        timestamp: DateTime.utc(2026, 10, 9),
        methodologyVersion: '1.0.0',
        serverId: 'https://speed.example.org/',
        result: okResult,
        sessionId: session.id,
        measurementId: measurementId,
        ratChanged: true,
      ),
    );

    final row = await db.select(db.speedTests).getSingle();
    expect(row.timestamp, '2026-10-09T00:00:00.000Z');
    expect(row.createdAt, '2026-10-09T01:00:00.000Z');
    expect(row.method, 'http-mc-1.0');
    expect(row.status, 'ok');
    expect(row.dlP90Mbps, 60.4);
    expect(row.ulBytes, 18000000);
    expect(row.ratChanged, isTrue);

    final record = (await store.watchSpeedTests().first).single;
    expect(record.id, 't1');
    expect(record.sessionId, session.id);
    expect(record.measurementId, measurementId);
    expect(record.serverId, 'https://speed.example.org/');
    expect(record.result.download!.meanMbps, 48.2);
    expect(record.result.upload!.peakMbps, 15.2);
    expect(record.result.dnsMs, 12.4);
    expect(record.ratChanged, isTrue);

    expect(await measurements.latestMeasurementId(session.id), measurementId);
    expect(await measurements.latestMeasurementId('none'), isNull);
  });

  test('failed tests store nulls, newest first', () async {
    const failed = SpeedTestResult(
      status: SpeedTestStatus.failed,
      method: 'http-mc-1.0',
      serverHost: 'h',
      streams: 4,
      error: 'DNS: unknown host',
    );
    for (final (id, day) in [('a', 1), ('b', 3), ('c', 2)]) {
      await store.saveSpeedTest(
        SpeedTestRecord(
          id: id,
          timestamp: DateTime.utc(2026, 10, day),
          methodologyVersion: '1.0.0',
          serverId: 'h',
          result: failed,
        ),
      );
    }
    final records = await store.watchSpeedTests(limit: 2).first;
    expect(records.map((r) => r.id), ['b', 'c']);
    expect(records.first.result.download, isNull);
    expect(records.first.result.error, 'DNS: unknown host');
    expect(records.first.sessionId, isNull);
  });

  test('settings round-trip and overwrite', () async {
    expect(await store.getSetting('speedtest.server_url'), isNull);
    await store.setSetting('speedtest.server_url', 'http://a/');
    await store.setSetting('speedtest.server_url', 'http://b/');
    expect(await store.getSetting('speedtest.server_url'), 'http://b/');
  });
}
