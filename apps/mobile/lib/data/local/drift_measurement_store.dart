import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/methodology.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/sample_rows.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/repositories/session_repository.dart';
import 'package:opennetiq_mobile/domain/services/sample_quality.dart';

/// Drift implementation of sessions and samples storage.
class DriftMeasurementStore implements SessionRepository, SampleRepository {
  DriftMeasurementStore(
    this._db, {
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? uuid7;

  final AppDatabase _db;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Last fix counted for distance, per session (in memory only).
  final Map<String, LocationFix> _lastDistanceFix = {};

  @override
  Future<MeasurementSession> createSession({
    required String deviceId,
    required String name,
    required SessionType type,
    required int samplingIntervalMs,
    String? operatorUnderTest,
    String? notes,
  }) async {
    final id = _newId();
    final now = formatUtc(_now());
    await _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            sessionId: id,
            deviceId: deviceId,
            name: name,
            sessionType: type.wireValue,
            status: SessionStatus.created.wireValue,
            samplingIntervalMs: samplingIntervalMs,
            operatorUnderTest: Value(operatorUnderTest),
            notes: Value(notes),
            methodologyVersion: methodologyVersion,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getSession(id))!;
  }

  @override
  Future<void> startRecording(String sessionId) async {
    final now = formatUtc(_now());
    await _db.customUpdate(
      'UPDATE sessions SET status = ?, started_at = COALESCE(started_at, ?), '
      'updated_at = ?, version = version + 1 WHERE session_id = ?',
      variables: [
        Variable.withString(SessionStatus.recording.wireValue),
        Variable.withString(now),
        Variable.withString(now),
        Variable.withString(sessionId),
      ],
      updates: {_db.sessions},
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<void> pauseRecording(String sessionId) async {
    final now = formatUtc(_now());
    await _db.customUpdate(
      'UPDATE sessions SET status = ?, updated_at = ?, version = version + 1 '
      'WHERE session_id = ?',
      variables: [
        Variable.withString(SessionStatus.paused.wireValue),
        Variable.withString(now),
        Variable.withString(sessionId),
      ],
      updates: {_db.sessions},
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<int> abortOrphanedSessions() {
    final now = formatUtc(_now());
    return _db.customUpdate(
      'UPDATE sessions SET status = ?, '
      'ended_at = COALESCE((SELECT MAX(s.timestamp) FROM samples s '
      'WHERE s.session_id = sessions.session_id), started_at, created_at), '
      'updated_at = ?, version = version + 1 '
      'WHERE status IN (?, ?, ?)',
      variables: [
        Variable.withString(SessionStatus.aborted.wireValue),
        Variable.withString(now),
        Variable.withString(SessionStatus.created.wireValue),
        Variable.withString(SessionStatus.recording.wireValue),
        Variable.withString(SessionStatus.paused.wireValue),
      ],
      updates: {_db.sessions},
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<void> finishRecording(String sessionId, {bool aborted = false}) async {
    final now = formatUtc(_now());
    final status = aborted ? SessionStatus.aborted : SessionStatus.completed;
    await _db.customUpdate(
      'UPDATE sessions SET status = ?, ended_at = ?, updated_at = ?, '
      'version = version + 1 WHERE session_id = ?',
      variables: [
        Variable.withString(status.wireValue),
        Variable.withString(now),
        Variable.withString(now),
        Variable.withString(sessionId),
      ],
      updates: {_db.sessions},
      updateKind: UpdateKind.update,
    );
    _lastDistanceFix.remove(sessionId);
  }

  @override
  Future<MeasurementSession?> getSession(String sessionId) async {
    final row = await _sessionQuery(sessionId).getSingleOrNull();
    return row == null ? null : sessionFromRow(row);
  }

  @override
  Stream<List<MeasurementSession>> watchSessions() {
    final query = _db.select(_db.sessions)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(sessionFromRow).toList(growable: false),
    );
  }

  @override
  Stream<MeasurementSession?> watchSession(String sessionId) =>
      _sessionQuery(sessionId)
          .watchSingleOrNull()
          .map((row) => row == null ? null : sessionFromRow(row));

  @override
  Future<void> deleteSession(String sessionId) async {
    await (_db.delete(
      _db.sessions,
    )..where((t) => t.sessionId.equals(sessionId))).go();
    _lastDistanceFix.remove(sessionId);
  }

  @override
  Future<void> deleteAllSessions() async {
    await _db.delete(_db.sessions).go();
    _lastDistanceFix.clear();
  }

  @override
  Future<String> recordSample({
    required String sessionId,
    required RadioSnapshot radio,
    LocationStatus? location,
  }) {
    final measurementId = _newId();
    final rows = buildSampleRows(
      sessionId: sessionId,
      measurementId: measurementId,
      createdAt: _now(),
      radio: radio,
      location: location,
      newId: _newId,
    );
    final fix = rows.fix;
    var stepM = 0.0;
    if (fix != null && SampleQuality.countsForDistance(location, fix)) {
      stepM = SampleQuality.stepM(_lastDistanceFix[sessionId], fix);
      _lastDistanceFix[sessionId] = fix;
    }
    return _db.transaction(() async {
      await _db.into(_db.samples).insert(rows.sample);
      await _db.batch((b) => b.insertAll(_db.cellObservations, rows.cells));
      await _db.customUpdate(
        'UPDATE sessions SET sample_count = sample_count + 1, '
        'distance_m = COALESCE(distance_m, 0) + ?, updated_at = ?, '
        'version = version + 1 WHERE session_id = ?',
        variables: [
          Variable.withReal(stepM),
          Variable.withString(formatUtc(_now())),
          Variable.withString(sessionId),
        ],
        updates: {_db.sessions},
        updateKind: UpdateKind.update,
      );
      return measurementId;
    });
  }

  @override
  Future<int> countSamples(String sessionId) async {
    final count = _db.samples.measurementId.count();
    final query = _db.selectOnly(_db.samples)
      ..addColumns([count])
      ..where(_db.samples.sessionId.equals(sessionId));
    return (await query.getSingle()).read(count) ?? 0;
  }

  @override
  Future<String?> latestMeasurementId(String sessionId) async {
    final query = _db.selectOnly(_db.samples)
      ..addColumns([_db.samples.measurementId])
      ..where(_db.samples.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.desc(_db.samples.timestamp)])
      ..limit(1);
    return (await query.getSingleOrNull())?.read(_db.samples.measurementId);
  }

  @override
  Future<List<DateTime>> sampleTimestamps(String sessionId) async {
    final query = _db.selectOnly(_db.samples)
      ..addColumns([_db.samples.timestamp])
      ..where(_db.samples.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(_db.samples.timestamp)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        if (parseUtc(row.read(_db.samples.timestamp)) case final DateTime t) t,
    ];
  }

  @override
  Future<List<SamplePoint>> loadSamplePoints(String sessionId) async {
    final samples = await _db
        .customSelect(
          'SELECT measurement_id, timestamp, lat, lon, network_type, '
          'gps_quality, quality_flag FROM samples WHERE session_id = ? '
          'ORDER BY timestamp',
          variables: [Variable.withString(sessionId)],
          readsFrom: {_db.samples},
        )
        .get();
    final cells = await _db
        .customSelect(
          'SELECT c.measurement_id, c.rat, c.rsrp_dbm, c.rscp_dbm, c.rssi_dbm '
          'FROM cell_observations c '
          'JOIN samples s ON s.measurement_id = c.measurement_id '
          'WHERE s.session_id = ? AND c.is_serving = 1 ORDER BY c.rowid',
          variables: [Variable.withString(sessionId)],
          readsFrom: {_db.samples, _db.cellObservations},
        )
        .get();
    final serving = <String, List<(Rat, double?)>>{};
    for (final c in cells) {
      final rat = Rat.fromWire(c.read<String>('rat'));
      if (rat == null) continue;
      final level = CellObservation.levelFor(
        rat,
        rsrpDbm: c.readNullable<double>('rsrp_dbm'),
        rscpDbm: c.readNullable<double>('rscp_dbm'),
        rssiDbm: c.readNullable<double>('rssi_dbm'),
      );
      (serving[c.read<String>('measurement_id')] ??= []).add((rat, level));
    }
    return [
      for (final row in samples)
        if (parseUtc(row.read<String>('timestamp')) case final DateTime ts)
          _samplePoint(row, ts, serving[row.read<String>('measurement_id')]),
    ];
  }

  static SamplePoint _samplePoint(
    QueryRow row,
    DateTime timestamp,
    List<(Rat, double?)>? serving,
  ) {
    final networkType = NetworkType.fromWire(row.read<String>('network_type'));
    final primary = _primary(serving, networkType);
    final flags = row.readNullable<String>('quality_flag') ?? '';
    return SamplePoint(
      timestamp: timestamp,
      networkType: networkType,
      lat: row.readNullable<double>('lat'),
      lon: row.readNullable<double>('lon'),
      mockLocation: flags.split('|').contains(SampleQuality.mockLocation),
      gpsQuality: GpsQuality.fromWire(row.readNullable<String>('gps_quality')),
      rat: primary?.$1,
      levelDbm: primary?.$2,
    );
  }

  /// Same rule as RadioSnapshot.primaryCell: LTE anchor in 5G NSA,
  /// otherwise the first serving cell.
  static (Rat, double?)? _primary(
    List<(Rat, double?)>? serving,
    NetworkType? networkType,
  ) {
    if (serving == null || serving.isEmpty) return null;
    if (networkType?.isNsa ?? false) {
      for (final c in serving) {
        if (c.$1 == Rat.lte) return c;
      }
    }
    return serving.first;
  }

  SimpleSelectStatement<$SessionsTable, SessionRow> _sessionQuery(
    String sessionId,
  ) => _db.select(_db.sessions)..where((t) => t.sessionId.equals(sessionId));

  static MeasurementSession sessionFromRow(SessionRow r) => MeasurementSession(
    id: r.sessionId,
    deviceId: r.deviceId,
    name: r.name,
    type: SessionType.fromWire(r.sessionType) ?? SessionType.drive,
    status: SessionStatus.fromWire(r.status) ?? SessionStatus.created,
    samplingIntervalMs: r.samplingIntervalMs,
    methodologyVersion: r.methodologyVersion,
    sampleCount: r.sampleCount,
    createdAt: parseUtc(r.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: parseUtc(r.updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
    operatorUnderTest: r.operatorUnderTest,
    notes: r.notes,
    startedAt: parseUtc(r.startedAt),
    endedAt: parseUtc(r.endedAt),
    distanceM: r.distanceM,
  );
}
