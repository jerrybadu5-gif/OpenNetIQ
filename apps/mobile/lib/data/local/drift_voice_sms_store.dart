import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/domain/repositories/voice_sms_repository.dart';

class DriftVoiceSmsStore implements VoiceSmsStore {
  DriftVoiceSmsStore(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<void> saveVoiceSmsTests(List<VoiceSmsRecord> records) {
    final created = formatUtc(_now());
    return _db.batch((b) {
      b.insertAll(_db.voiceSmsTests, [
        for (final r in records) companion(r, created),
      ]);
    });
  }

  static VoiceSmsTestsCompanion companion(VoiceSmsRecord r, String created) {
    final v = r.result;
    return VoiceSmsTestsCompanion.insert(
      testId: r.id,
      sessionId: Value(r.sessionId),
      measurementId: Value(r.measurementId),
      timestamp: formatUtc(r.timestamp),
      kind: v.kind.wireValue,
      methodologyVersion: r.methodologyVersion,
      label: v.label,
      targetMasked: v.targetMasked,
      status: v.status.wireValue,
      outcome: v.outcome,
      error: Value(v.error),
      windowS: Value(v.windowS),
      callMs: Value(v.callMs),
      setupMs: Value(v.setupMs),
      connectedS: Value(v.connectedS),
      dropped: Value(v.dropped),
      voiceRat: Value(v.voiceRat),
      loopback: Value(v.loopback),
      sendMs: Value(v.sendMs),
      deliveryMs: Value(v.deliveryMs),
      receiveMs: Value(v.receiveMs),
      createdAt: created,
    );
  }

  @override
  Stream<List<VoiceSmsRecord>> watchVoiceSmsTests({int limit = 50}) =>
      (_db.select(_db.voiceSmsTests)
            ..orderBy([
              (t) => OrderingTerm.desc(t.timestamp),
              (t) => OrderingTerm.desc(t.testId),
            ])
            ..limit(limit))
          .watch()
          .map((rows) => [for (final r in rows) ?recordOf(r)]);

  static VoiceSmsRecord? recordOf(VoiceSmsTestRow r) {
    final kind = VoiceSmsKind.fromWire(r.kind);
    final at = parseUtc(r.timestamp);
    final status = TestStatus.fromWire(r.status);
    if (kind == null || at == null || status == null) return null;
    return VoiceSmsRecord(
      id: r.testId,
      timestamp: at,
      methodologyVersion: r.methodologyVersion,
      sessionId: r.sessionId,
      measurementId: r.measurementId,
      result: VoiceSmsResult(
        kind: kind,
        label: r.label,
        targetMasked: r.targetMasked,
        status: status,
        outcome: r.outcome,
        error: r.error,
        windowS: r.windowS,
        callMs: r.callMs,
        setupMs: r.setupMs,
        connectedS: r.connectedS,
        dropped: r.dropped,
        voiceRat: r.voiceRat,
        loopback: r.loopback,
        sendMs: r.sendMs,
        deliveryMs: r.deliveryMs,
        receiveMs: r.receiveMs,
      ),
    );
  }
}
