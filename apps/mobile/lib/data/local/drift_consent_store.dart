import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/domain/repositories/consent_repository.dart';

class DriftConsentStore implements ConsentRepository, MeasurementDataEraser {
  DriftConsentStore(
    this._db, {
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? uuid7;

  final AppDatabase _db;
  final DateTime Function() _now;
  final String Function() _newId;

  @override
  Future<void> record(
    Set<ConsentScope> scopes, {
    required bool granted,
    required String policyVersion,
  }) {
    final at = formatUtc(_now());
    return _db.batch((b) {
      b.insertAll(_db.consentLog, [
        for (final s in scopes)
          ConsentLogCompanion.insert(
            consentId: _newId(),
            scope: s.wireValue,
            granted: granted,
            policyVersion: policyVersion,
            timestamp: at,
          ),
      ]);
    });
  }

  @override
  Future<List<ConsentRecord>> ledger() async {
    final rows =
        await (_db.select(_db.consentLog)..orderBy([
              (c) => OrderingTerm.desc(c.timestamp),
              (c) => OrderingTerm.desc(c.consentId),
            ]))
            .get();
    return [
      for (final r in rows)
        if ((ConsentScope.fromWire(r.scope), parseUtc(r.timestamp)) case (
          final ConsentScope scope,
          final DateTime at,
        ))
          ConsentRecord(
            id: r.consentId,
            scope: scope,
            granted: r.granted,
            policyVersion: r.policyVersion,
            timestamp: at,
          ),
    ];
  }

  @override
  Future<void> eraseMeasurements() => _db.transaction(() async {
    // Tests first: unlinked tests have no session to cascade from.
    await _db.delete(_db.speedTests).go();
    await _db.delete(_db.latencyTests).go();
    await _db.delete(_db.qoeTests).go();
    await _db.delete(_db.sessions).go(); // cascades samples and cells
  });
}
