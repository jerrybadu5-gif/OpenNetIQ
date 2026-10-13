import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/data/export/session_export_builder.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';

/// Reads one session with everything linked to it, for export (#23).
class DriftExportStore {
  const DriftExportStore(this._db);

  final AppDatabase _db;

  /// Null when the session does not exist.
  Future<SessionExportData?> load(String sessionId) =>
      _db.transaction(() async {
        final session = await (_db.select(
          _db.sessions,
        )..where((s) => s.sessionId.equals(sessionId))).getSingleOrNull();
        if (session == null) return null;
        final device = await (_db.select(
          _db.devices,
        )..where((d) => d.deviceId.equals(session.deviceId))).getSingleOrNull();
        final samples =
            await (_db.select(_db.samples)
                  ..where((s) => s.sessionId.equals(sessionId))
                  ..orderBy([(s) => OrderingTerm.asc(s.timestamp)]))
                .get();
        final cellRows =
            await (_db.select(_db.cellObservations).join([
                    innerJoin(
                      _db.samples,
                      _db.samples.measurementId.equalsExp(
                        _db.cellObservations.measurementId,
                      ),
                    ),
                  ])
                  ..where(_db.samples.sessionId.equals(sessionId))
                  ..orderBy([OrderingTerm.asc(_db.cellObservations.rowId)]))
                .get();
        final cells = <String, List<CellObservationRow>>{};
        for (final r in cellRows) {
          final c = r.readTable(_db.cellObservations);
          (cells[c.measurementId] ??= []).add(c);
        }
        final speed =
            await (_db.select(_db.speedTests)
                  ..where((t) => t.sessionId.equals(sessionId))
                  ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
                .get();
        final latency =
            await (_db.select(_db.latencyTests)
                  ..where((t) => t.sessionId.equals(sessionId))
                  ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
                .get();
        return SessionExportData(
          session: session,
          device: device,
          samples: samples,
          cells: cells,
          speedTests: speed,
          latencyTests: latency,
        );
      });
}
