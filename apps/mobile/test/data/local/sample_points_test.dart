import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_device_registry.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/data/mappers/radio_snapshot_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/location_fixtures.dart';
import '../../fixtures/radio_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftMeasurementStore store;
  late String sessionId;

  setUp(() async {
    db = memoryDatabase();
    store = DriftMeasurementStore(
      db,
      now: () => DateTime.utc(2026, 10, 8, 1),
      newId: sequentialIds(),
    );
    final deviceId = await DriftDeviceRegistry(db).ensureDevice(testDevice);
    sessionId = (await store.createSession(
      deviceId: deviceId,
      name: 'Route',
      type: SessionType.drive,
      samplingIntervalMs: 1000,
    )).id;
  });
  tearDown(() => db.close());

  test('positions, levels and network type per sample, oldest first', () async {
    await store.recordSample(sessionId: sessionId, radio: snapshotAt(1));
    await store.recordSample(
      sessionId: sessionId,
      radio: snapshot(),
      location: locationStatus(),
    );

    final points = await store.loadSamplePoints(sessionId);
    expect(points, hasLength(2));

    final first = points.first;
    expect(first.timestamp, DateTime.utc(2026, 10, 8, 1));
    expect(first.hasPosition, isTrue);
    expect(first.lat, closeTo(-9.4438, 1e-9));
    expect(first.gpsQuality, GpsQuality.good);
    expect(first.rat, Rat.lte);
    expect(first.levelDbm, -95);
    expect(first.networkType, NetworkType.lte);

    expect(points.last.hasPosition, isFalse);
  });

  test('5G NSA uses the LTE anchor even when NR is listed first', () async {
    await store.recordSample(
      sessionId: sessionId,
      radio: RadioSnapshotMapper.fromChannel(
        snapshotPayload(
          networkType: 'NR_NSA',
          cells: [nrCell(serving: true), lteCell(rsrp: -97)],
        ),
      ),
    );
    final point = (await store.loadSamplePoints(sessionId)).single;
    expect(point.networkType?.isNsa, isTrue);
    expect(point.rat, Rat.lte);
    expect(point.levelDbm, -97);
  });

  test('SA / single serving cell uses the first serving cell', () async {
    await store.recordSample(
      sessionId: sessionId,
      radio: RadioSnapshotMapper.fromChannel(
        snapshotPayload(
          networkType: 'NR_SA',
          cells: [nrCell(serving: true, ssRsrp: -88), lteCell(serving: false)],
        ),
      ),
    );
    final point = (await store.loadSamplePoints(sessionId)).single;
    expect(point.rat, Rat.nr);
    expect(point.levelDbm, -88);
  });

  test(
    'mock locations are flagged and samples without cells have no level',
    () async {
      await store.recordSample(
        sessionId: sessionId,
        radio: snapshot(cells: const []),
        location: locationStatus(mock: true),
      );
      final point = (await store.loadSamplePoints(sessionId)).single;
      expect(point.mockLocation, isTrue);
      expect(point.hasPosition, isFalse);
      expect(point.rat, isNull);
      expect(point.levelDbm, isNull);
    },
  );

  test('unknown session yields no points', () async {
    expect(await store.loadSamplePoints('missing'), isEmpty);
  });
}
