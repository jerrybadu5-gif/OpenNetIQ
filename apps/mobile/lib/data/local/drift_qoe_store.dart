import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/domain/repositories/qoe_repository.dart';

class DriftQoeStore implements QoeStore {
  DriftQoeStore(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<void> saveQoeTests(List<QoeRecord> records) {
    final created = formatUtc(_now());
    return _db.batch((b) {
      b.insertAll(_db.qoeTests, [
        for (final r in records) _companion(r, created),
      ]);
    });
  }

  static QoeTestsCompanion _companion(QoeRecord r, String created) {
    final q = r.result;
    return QoeTestsCompanion.insert(
      testId: r.id,
      sessionId: Value(r.sessionId),
      measurementId: Value(r.measurementId),
      timestamp: formatUtc(r.timestamp),
      kind: q.kind.wireValue,
      methodologyVersion: r.methodologyVersion,
      label: q.label,
      target: q.target,
      status: q.status.wireValue,
      error: Value(q.error),
      totalMs: Value(q.totalMs),
      dnsMs: Value(q.dnsMs),
      connectMs: Value(q.connectMs),
      tlsMs: Value(q.tlsMs),
      ttfbMs: Value(q.ttfbMs),
      domMs: Value(q.domMs),
      httpStatus: Value(q.httpStatus),
      startDelayMs: Value(q.startDelayMs),
      rebufferCount: Value(q.rebufferCount),
      rebufferMs: Value(q.rebufferMs),
      playedMs: Value(q.playedMs),
      bitrateKbps: Value(q.bitrateKbps),
      resolution: Value(q.resolution),
      bytes: Value(q.bytes),
      rateMbps: Value(q.rateMbps),
      direction: Value(q.direction),
      createdAt: created,
    );
  }

  @override
  Stream<List<QoeRecord>> watchQoeTests({int limit = 50}) =>
      (_db.select(_db.qoeTests)
            ..orderBy([
              (t) => OrderingTerm.desc(t.timestamp),
              (t) => OrderingTerm.desc(t.testId),
            ])
            ..limit(limit))
          .watch()
          .map((rows) => [for (final r in rows) ?recordOf(r)]);

  static QoeRecord? recordOf(QoeTestRow r) {
    final kind = QoeKind.fromWire(r.kind);
    final at = parseUtc(r.timestamp);
    final status = TestStatus.fromWire(r.status);
    if (kind == null || at == null || status == null) return null;
    return QoeRecord(
      id: r.testId,
      timestamp: at,
      methodologyVersion: r.methodologyVersion,
      sessionId: r.sessionId,
      measurementId: r.measurementId,
      result: QoeResult(
        kind: kind,
        label: r.label,
        target: r.target,
        status: status,
        error: r.error,
        totalMs: r.totalMs,
        dnsMs: r.dnsMs,
        connectMs: r.connectMs,
        tlsMs: r.tlsMs,
        ttfbMs: r.ttfbMs,
        domMs: r.domMs,
        httpStatus: r.httpStatus,
        startDelayMs: r.startDelayMs,
        rebufferCount: r.rebufferCount,
        rebufferMs: r.rebufferMs,
        playedMs: r.playedMs,
        bitrateKbps: r.bitrateKbps,
        resolution: r.resolution,
        bytes: r.bytes,
        rateMbps: r.rateMbps,
        direction: r.direction,
      ),
    );
  }
}
