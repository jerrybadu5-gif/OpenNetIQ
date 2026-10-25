import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';

const exportSessionId = 'sess-1';
const ts = '2026-10-13T01:00:00.000Z';

/// A finished drive: 3 samples (NSA with NR leg + neighbour, LTE only,
/// no fix), one speed test and one latency test linked to samples.
Future<void> seedExportSession(AppDatabase db, {String name = 'POM Route 1'}) =>
    db.transaction(() async {
      await db
          .into(db.devices)
          .insert(
            DevicesCompanion.insert(
              deviceId: 'dev-1',
              manufacturer: 'Samsung',
              model: 'SM-A546E',
              androidVersion: '14',
              apiLevel: 34,
              appVersion: '1.0.0',
              createdAt: ts,
              updatedAt: ts,
            ),
          );
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              sessionId: exportSessionId,
              deviceId: 'dev-1',
              name: name,
              sessionType: 'drive',
              status: 'completed',
              samplingIntervalMs: 1000,
              methodologyVersion: '1.0.0',
              startedAt: const Value('2026-10-13T01:00:00.000Z'),
              endedAt: const Value('2026-10-13T01:00:03.000Z'),
              sampleCount: const Value(3),
              createdAt: ts,
              updatedAt: ts,
            ),
          );
      Future<void> sample(
        String id,
        String at,
        String network, {
        double? lat,
        double? lon,
        double? alt,
      }) => db
          .into(db.samples)
          .insert(
            SamplesCompanion.insert(
              measurementId: id,
              sessionId: exportSessionId,
              timestamp: at,
              networkType: network,
              createdAt: at,
              lat: Value(lat),
              lon: Value(lon),
              altitudeM: Value(alt),
              gpsQuality: Value(lat == null ? 'NONE' : 'GOOD'),
              operatorName: const Value('Digicel, PNG'),
              mcc: const Value('537'),
              mnc: const Value('03'),
              qualityFlag: Value(lat == null ? 'NO_FIX' : null),
            ),
          );
      Future<void> cell(
        String id,
        String measurement,
        String rat, {
        bool serving = true,
        double? rsrp,
        int? pci,
      }) => db
          .into(db.cellObservations)
          .insert(
            CellObservationsCompanion.insert(
              observationId: id,
              measurementId: measurement,
              isServing: serving,
              rat: rat,
              rsrpDbm: Value(rsrp),
              pciPscBsic: Value(pci),
              enbId: Value(rat == 'LTE' && serving ? 12345 : null),
              gnbId: Value(rat == 'NR' ? 777 : null),
            ),
          );
      // Sample order deliberately differs from insertion order.
      await sample(
        'm2',
        '2026-10-13T01:00:02.000Z',
        'LTE',
        lat: -9.44,
        lon: 147.18,
      );
      await sample(
        'm1',
        '2026-10-13T01:00:01.000Z',
        'NR_NSA',
        lat: -9.45,
        lon: 147.17,
        alt: 40,
      );
      await sample('m3', '2026-10-13T01:00:03.000Z', 'LTE');
      await cell('c1', 'm1', 'NR', rsrp: -95, pci: 501);
      await cell('c2', 'm1', 'LTE', rsrp: -88, pci: 101);
      await cell('c3', 'm1', 'LTE', serving: false, rsrp: -101, pci: 102);
      await cell('c4', 'm2', 'LTE', rsrp: -112, pci: 101);
      await db
          .into(db.speedTests)
          .insert(
            SpeedTestsCompanion.insert(
              testId: 'sp-1',
              sessionId: const Value(exportSessionId),
              measurementId: const Value('m2'),
              timestamp: '2026-10-13T01:00:02.500Z',
              method: 'http-mc-1.0',
              methodologyVersion: '1.0.0',
              serverId: 'https://speed.example.org/backend/',
              serverHost: 'speed.example.org',
              streams: 4,
              dlMeanMbps: const Value(48.2),
              ulMeanMbps: const Value(12.1),
              status: 'ok',
              error: const Value('upload: "slow", retried'),
              createdAt: ts,
            ),
          );
      await db
          .into(db.qoeTests)
          .insert(
            QoeTestsCompanion.insert(
              testId: 'qoe-1',
              sessionId: const Value(exportSessionId),
              measurementId: const Value('m1'),
              timestamp: '2026-10-13T01:00:01.800Z',
              kind: 'web',
              methodologyVersion: '1.0.0',
              label: 'Google',
              target: 'https://www.google.com/',
              status: 'ok',
              totalMs: const Value(1800),
              ttfbMs: const Value(210),
              createdAt: ts,
            ),
          );
      await db
          .into(db.voiceSmsTests)
          .insert(
            VoiceSmsTestsCompanion.insert(
              testId: 'vs-1',
              sessionId: const Value(exportSessionId),
              measurementId: const Value('m1'),
              timestamp: '2026-10-13T01:00:02.000Z',
              kind: 'call',
              methodologyVersion: '1.0.0',
              label: 'Line A',
              targetMasked: '••67',
              status: 'ok',
              outcome: 'completed',
              windowS: const Value(45),
              setupMs: const Value(5200),
              connectedS: const Value(39),
              dropped: const Value(false),
              voiceRat: const Value('VoLTE>UMTS'),
              createdAt: ts,
            ),
          );
      await db
          .into(db.latencyTests)
          .insert(
            LatencyTestsCompanion.insert(
              testId: 'lt-1',
              sessionId: const Value(exportSessionId),
              measurementId: const Value('m1'),
              timestamp: '2026-10-13T01:00:01.500Z',
              protocol: 'tcp',
              methodologyVersion: '1.0.0',
              target: 'speed.example.org:443',
              probesSent: 3,
              probesReceived: 2,
              medianMs: const Value(27.4),
              rawRttsMs: const Value('[20.0,null,30.0]'),
              status: 'ok',
              createdAt: ts,
            ),
          );
    });
