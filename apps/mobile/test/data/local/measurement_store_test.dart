import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_device_registry.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/data/mappers/location_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/location_fixtures.dart';
import '../../fixtures/radio_fixtures.dart';

LocationStatus locationAt({
  double lat = -9.4438,
  double lon = 147.1803,
  String quality = 'GOOD',
  bool mock = false,
  String timestamp = '2026-10-08T01:00:00.000Z',
}) {
  final payload = locationPayload(quality: quality)
    ..['timestamp'] = timestamp
    ..['fix'] = (fixPayload(mock: mock)
      ..['lat'] = lat
      ..['lon'] = lon);
  return LocationMapper.fromChannel(payload);
}

void main() {
  late AppDatabase db;
  late DriftMeasurementStore store;
  late String deviceId;

  setUp(() async {
    db = memoryDatabase();
    final clock = DateTime.utc(2026, 10, 8, 1);
    store = DriftMeasurementStore(db, now: () => clock, newId: sequentialIds());
    deviceId = await DriftDeviceRegistry(db).ensureDevice(testDevice);
  });
  tearDown(() => db.close());

  Future<MeasurementSession> newSession() => store.createSession(
    deviceId: deviceId,
    name: 'Test route',
    type: SessionType.drive,
    samplingIntervalMs: 1000,
    operatorUnderTest: 'Digicel PNG',
  );

  group('sessions', () {
    test('create, start and finish', () async {
      final s = await newSession();
      expect(s.status, SessionStatus.created);
      expect(s.methodologyVersion, '1.0.0');
      expect(s.sampleCount, 0);
      expect(s.operatorUnderTest, 'Digicel PNG');

      await store.startRecording(s.id);
      final recording = await store.getSession(s.id);
      expect(recording!.status, SessionStatus.recording);
      expect(recording.startedAt, DateTime.utc(2026, 10, 8, 1));

      await store.finishRecording(s.id);
      final done = await store.getSession(s.id);
      expect(done!.status, SessionStatus.completed);
      expect(done.endedAt, isNotNull);
      expect(done.duration(), Duration.zero);

      final s2 = await newSession();
      await store.finishRecording(s2.id, aborted: true);
      expect((await store.getSession(s2.id))!.status, SessionStatus.aborted);
    });

    test('watchSessions lists newest first and reacts to deletes', () async {
      final a = await newSession();
      final b = await newSession();
      final lists = <List<String>>[];
      final sub = store.watchSessions().listen(
        (l) => lists.add(l.map((s) => s.id).toList()),
      );
      await pumpEventQueue();
      await store.deleteSession(a.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(lists.first.toSet(), {a.id, b.id});
      expect(lists.last, [b.id]);
    });

    test('deleteAllSessions removes everything', () async {
      await newSession();
      await newSession();
      await store.deleteAllSessions();
      expect(await store.watchSessions().first, isEmpty);
    });

    test('watchSession emits null for unknown ids', () async {
      expect(await store.watchSession('missing').first, isNull);
    });
  });

  group('recordSample', () {
    test('stores sample, location and every cell', () async {
      final s = await newSession();
      final id = await store.recordSample(
        sessionId: s.id,
        radio: snapshot(
          networkType: 'NR_NSA',
          cells: [lteCell(), nrCell(), lteCell(serving: false, pci: 7)],
        ),
        location: locationAt(),
      );

      final row = await (db.select(
        db.samples,
      )..where((t) => t.measurementId.equals(id))).getSingle();
      expect(row.sessionId, s.id);
      expect(row.timestamp, '2026-10-08T01:00:00.000Z');
      expect(row.networkType, 'NR_NSA');
      expect(row.operatorName, 'Digicel PNG');
      expect(row.mcc, '537');
      expect(row.mnc, '03');
      expect(row.lat, -9.4438);
      expect(row.lon, 147.1803);
      expect(row.hAccuracyM, 4.2);
      expect(row.satellitesUsed, 9);
      expect(row.gpsQuality, 'GOOD');
      expect(row.isRoaming, isFalse);
      expect(row.radioTimestamp, '2026-10-08T00:59:59.800Z');
      expect(row.qualityFlag, isNull);

      final cells = await (db.select(
        db.cellObservations,
      )..where((t) => t.measurementId.equals(id))).get();
      expect(cells, hasLength(3));
      final lte = cells.firstWhere((c) => c.rat == 'LTE' && c.isServing);
      expect(lte.rsrpDbm, -95);
      expect(lte.enbId, 107183);
      expect(lte.pciPscBsic, 301);
      final nr = cells.firstWhere((c) => c.rat == 'NR');
      expect(nr.gnbId, 11259375);
      expect(nr.csiRsrpDbm, -99);

      final updated = await store.getSession(s.id);
      expect(updated!.sampleCount, 1);
      expect(await store.countSamples(s.id), 1);
    });

    test('no location, stale location and mock location are flagged', () async {
      final s = await newSession();
      Future<String?> flagFor(LocationStatus? location) async {
        final id = await store.recordSample(
          sessionId: s.id,
          radio: snapshot(qualityFlag: 'STALE'),
          location: location,
        );
        final row = await (db.select(
          db.samples,
        )..where((t) => t.measurementId.equals(id))).getSingle();
        return '${row.qualityFlag}|${row.gpsQuality}|${row.lat}';
      }

      expect(await flagFor(null), 'NO_GPS_FIX|STALE|NONE|null');
      expect(
        await flagFor(locationAt(timestamp: '2026-10-08T00:59:50.000Z')),
        'NO_GPS_FIX|STALE|NONE|null',
      );
      expect(
        await flagFor(locationAt(mock: true)),
        'MOCK_LOCATION|STALE|GOOD|-9.4438',
      );
      expect(await store.countSamples(s.id), 3);
    });

    test('distance accumulates GOOD fixes and ignores glitches', () async {
      final s = await newSession();
      Future<void> at(double lat, {String quality = 'GOOD'}) =>
          store.recordSample(
            sessionId: s.id,
            radio: snapshot(),
            location: locationAt(lat: lat, quality: quality),
          );

      await at(-9.4400);
      await at(-9.4410); // +111 m
      await at(-9.4420, quality: 'POOR'); // not counted
      await at(-9.4430); // +222 m from last counted fix
      await at(-9.5000); // 6.3 km jump: glitch, ignored

      final distance = (await store.getSession(s.id))!.distanceM!;
      expect(distance, closeTo(333.6, 1.0));
    });

    test('deleting a session cascades to samples and cells', () async {
      final s = await newSession();
      await store.recordSample(sessionId: s.id, radio: snapshot());
      await store.deleteSession(s.id);

      expect(await db.select(db.samples).get(), isEmpty);
      expect(await db.select(db.cellObservations).get(), isEmpty);
    });

    test('sustains at least 50 samples per second', () async {
      final s = await newSession();
      final radio = snapshot(
        cells: [lteCell(), lteCell(serving: false, pci: 7), nrCell()],
      );
      final location = locationAt();
      const n = 300;
      final watch = Stopwatch()..start();
      for (var i = 0; i < n; i++) {
        await store.recordSample(
          sessionId: s.id,
          radio: radio,
          location: location,
        );
      }
      watch.stop();

      expect(await store.countSamples(s.id), n);
      final perSecond = n / (watch.elapsedMilliseconds / 1000);
      expect(perSecond, greaterThan(50), reason: '$perSecond samples/s');
    });
  });
}
