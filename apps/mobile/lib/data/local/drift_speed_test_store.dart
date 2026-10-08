import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/domain/repositories/speed_test_repository.dart';

/// `speed_tests` rows (DATA-DICTIONARY.md) and `app_settings`.
class DriftSpeedTestStore implements SpeedTestStore, SettingsRepository {
  DriftSpeedTestStore(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<void> saveSpeedTest(SpeedTestRecord record) async {
    final r = record.result;
    final dl = r.download;
    final ul = r.upload;
    await _db
        .into(_db.speedTests)
        .insert(
          SpeedTestsCompanion.insert(
            testId: record.id,
            sessionId: Value(record.sessionId),
            measurementId: Value(record.measurementId),
            timestamp: formatUtc(record.timestamp),
            method: r.method,
            methodologyVersion: record.methodologyVersion,
            serverId: record.serverId,
            serverHost: r.serverHost,
            streams: r.streams,
            dnsMs: Value(r.dnsMs),
            tcpConnectMs: Value(r.tcpConnectMs),
            dlMeanMbps: Value(dl?.meanMbps),
            dlMedianMbps: Value(dl?.medianMbps),
            dlP10Mbps: Value(dl?.p10Mbps),
            dlP90Mbps: Value(dl?.p90Mbps),
            dlPeakMbps: Value(dl?.peakMbps),
            dlBytes: Value(dl?.bytes),
            ulMeanMbps: Value(ul?.meanMbps),
            ulMedianMbps: Value(ul?.medianMbps),
            ulP10Mbps: Value(ul?.p10Mbps),
            ulP90Mbps: Value(ul?.p90Mbps),
            ulPeakMbps: Value(ul?.peakMbps),
            ulBytes: Value(ul?.bytes),
            ratChanged: Value(record.ratChanged),
            status: r.status.wireValue,
            error: Value(r.error),
            createdAt: formatUtc(_now()),
          ),
        );
  }

  @override
  Stream<List<SpeedTestRecord>> watchSpeedTests({int limit = 50}) {
    final query = _db.select(_db.speedTests)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows.map(fromRow).toList(growable: false),
    );
  }

  static SpeedTestRecord fromRow(SpeedTestRow row) {
    ThroughputResult? direction(
      double? mean,
      double? median,
      double? p10,
      double? p90,
      double? peak,
      int? bytes,
    ) => mean == null
        ? null
        : ThroughputResult(
            meanMbps: mean,
            medianMbps: median ?? mean,
            p10Mbps: p10 ?? mean,
            p90Mbps: p90 ?? mean,
            peakMbps: peak ?? mean,
            bytes: bytes ?? 0,
          );
    return SpeedTestRecord(
      id: row.testId,
      sessionId: row.sessionId,
      measurementId: row.measurementId,
      timestamp:
          parseUtc(row.timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0),
      methodologyVersion: row.methodologyVersion,
      serverId: row.serverId,
      ratChanged: row.ratChanged,
      result: SpeedTestResult(
        status: SpeedTestStatus.fromWire(row.status) ?? SpeedTestStatus.failed,
        method: row.method,
        serverHost: row.serverHost,
        streams: row.streams,
        dnsMs: row.dnsMs,
        tcpConnectMs: row.tcpConnectMs,
        download: direction(
          row.dlMeanMbps,
          row.dlMedianMbps,
          row.dlP10Mbps,
          row.dlP90Mbps,
          row.dlPeakMbps,
          row.dlBytes,
        ),
        upload: direction(
          row.ulMeanMbps,
          row.ulMedianMbps,
          row.ulP10Mbps,
          row.ulP90Mbps,
          row.ulPeakMbps,
          row.ulBytes,
        ),
        error: row.error,
      ),
    );
  }

  @override
  Future<String?> getSetting(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.settingKey.equals(key))).getSingleOrNull();
    return row?.settingValue;
  }

  @override
  Future<void> setSetting(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          settingKey: key,
          settingValue: value,
          updatedAt: formatUtc(_now()),
        ),
      );
}
