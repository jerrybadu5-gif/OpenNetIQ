import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_consent_store.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/export_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftConsentStore store;
  var minute = 0;

  setUp(() {
    db = memoryDatabase();
    minute = 0;
    store = DriftConsentStore(
      db,
      now: () => DateTime.utc(2026, 10, 13, 1, minute++),
      newId: sequentialIds('c'),
    );
  });
  tearDown(() => db.close());

  test('records one row per scope, ledger newest first', () async {
    await store.record(
      ConsentScope.measurement,
      granted: true,
      policyVersion: '1.0',
    );
    await store.record(
      {ConsentScope.location},
      granted: false,
      policyVersion: '1.0',
    );
    final rows = await db.select(db.consentLog).get();
    expect(rows, hasLength(3));
    expect(rows.first.timestamp, '2026-10-13T01:00:00.000Z');
    final ledger = await store.ledger();
    expect(ledger.first.scope, ConsentScope.location);
    expect(ledger.first.granted, isFalse);
    expect(ledger.map((r) => r.policyVersion).toSet(), {'1.0'});
    final status = ConsentStatus.fromLedger('1.0', ledger);
    expect(status.measurement, isFalse);
  });

  test('erase removes measurements, keeps consent and devices', () async {
    await seedExportSession(db);
    await db
        .into(db.speedTests)
        .insert(
          SpeedTestsCompanion.insert(
            testId: 'unlinked',
            timestamp: ts,
            method: 'http-mc-1.0',
            methodologyVersion: '1.0.0',
            serverId: 's',
            serverHost: 's',
            streams: 4,
            status: 'ok',
            createdAt: ts,
          ),
        );
    await store.record(
      ConsentScope.measurement,
      granted: true,
      policyVersion: '1.0',
    );
    await store.eraseMeasurements();
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await db.select(db.samples).get(), isEmpty);
    expect(await db.select(db.cellObservations).get(), isEmpty);
    expect(await db.select(db.speedTests).get(), isEmpty);
    expect(await db.select(db.latencyTests).get(), isEmpty);
    expect(await db.select(db.consentLog).get(), hasLength(2));
    expect(await db.select(db.devices).get(), hasLength(1));
  });

  test('unknown scopes or bad timestamps are skipped', () async {
    await db.customStatement('PRAGMA ignore_check_constraints = ON');
    await db
        .into(db.consentLog)
        .insert(
          ConsentLogCompanion.insert(
            consentId: 'x',
            scope: 'mystery',
            granted: true,
            policyVersion: '1.0',
            timestamp: '2026-10-13 01:00',
          ),
        );
    expect(await store.ledger(), isEmpty);
  });
}
