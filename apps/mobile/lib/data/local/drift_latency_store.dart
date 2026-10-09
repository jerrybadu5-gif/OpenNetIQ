import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/mappers/latency_test_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/domain/repositories/latency_test_repository.dart';

/// `latency_tests` rows (DATA-DICTIONARY.md); raw RTTs as a JSON array.
class DriftLatencyStore implements LatencyStore {
  DriftLatencyStore(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<void> saveLatencyTests(List<LatencyRecord> records) =>
      _db.transaction(() async {
        final createdAt = formatUtc(_now());
        for (final record in records) {
          final r = record.result;
          await _db
              .into(_db.latencyTests)
              .insert(
                LatencyTestsCompanion.insert(
                  testId: record.id,
                  sessionId: Value(record.sessionId),
                  measurementId: Value(record.measurementId),
                  timestamp: formatUtc(record.timestamp),
                  protocol: r.protocol.wireValue,
                  methodologyVersion: record.methodologyVersion,
                  target: r.target,
                  probesSent: r.probesSent,
                  probesReceived: r.probesReceived,
                  minMs: Value(r.minMs),
                  maxMs: Value(r.maxMs),
                  meanMs: Value(r.meanMs),
                  medianMs: Value(r.medianMs),
                  p95Ms: Value(r.p95Ms),
                  jitterMs: Value(r.jitterMs),
                  packetLossPct: Value(r.packetLossPct),
                  rawRttsMs: Value(jsonEncode(r.rawRttsMs)),
                  status: r.status.wireValue,
                  createdAt: createdAt,
                ),
              );
        }
      });

  @override
  Stream<List<LatencyRecord>> watchLatencyTests({int limit = 50}) {
    final query = _db.select(_db.latencyTests)
      ..orderBy([
        (t) => OrderingTerm.desc(t.timestamp),
        (t) => OrderingTerm.asc(t.protocol),
      ])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows.map(fromRow).toList(growable: false),
    );
  }

  static LatencyRecord fromRow(LatencyTestRow row) {
    final raw = row.rawRttsMs;
    final decoded = raw == null ? null : jsonDecode(raw);
    return LatencyRecord(
      id: row.testId,
      sessionId: row.sessionId,
      measurementId: row.measurementId,
      timestamp:
          parseUtc(row.timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0),
      methodologyVersion: row.methodologyVersion,
      result: LatencyResult(
        protocol:
            LatencyProtocol.fromWire(row.protocol) ?? LatencyProtocol.tcp,
        method: 'lat-1.0',
        target: row.target,
        probesSent: row.probesSent,
        probesReceived: row.probesReceived,
        rawRttsMs: decoded is List<Object?>
            ? LatencyTestMapper.rtts(decoded)
            : const [],
        status: TestStatus.fromWire(row.status) ?? TestStatus.failed,
        minMs: row.minMs,
        maxMs: row.maxMs,
        meanMs: row.meanMs,
        medianMs: row.medianMs,
        p95Ms: row.p95Ms,
        jitterMs: row.jitterMs,
        packetLossPct: row.packetLossPct,
      ),
    );
  }
}
