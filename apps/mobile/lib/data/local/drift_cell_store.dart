import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/services/sample_quality.dart';

/// Cell sightings (cell_observations joined with samples) for the cell
/// scan and site estimation (issue #27).
class DriftCellStore {
  const DriftCellStore(this._db);

  final AppDatabase _db;

  /// One session, or every session when [sessionId] is null. Mock-location
  /// fixes and fixes of quality NONE are dropped (cell kept, no position).
  Future<List<CellSighting>> loadSightings({String? sessionId}) async {
    final rows = await _db
        .customSelect(
          'SELECT c.measurement_id, c.is_serving, c.rat, c.mcc, c.mnc, '
          'c.lac_tac, c.cell_id, c.enb_id, c.gnb_id, c.pci_psc_bsic, c.arfcn, '
          'c.band, c.rsrp_dbm, c.rscp_dbm, c.rssi_dbm, c.timing_advance, '
          's.timestamp, s.lat, s.lon, s.gps_quality, s.quality_flag '
          'FROM cell_observations c '
          'JOIN samples s ON s.measurement_id = c.measurement_id '
          '${sessionId == null ? '' : 'WHERE s.session_id = ? '}'
          'ORDER BY s.timestamp, c.rowid',
          variables: [if (sessionId != null) Variable.withString(sessionId)],
          readsFrom: {_db.samples, _db.cellObservations},
        )
        .get();
    return [
      for (final r in rows)
        if ((
              Rat.fromWire(r.read<String>('rat')),
              parseUtc(r.read<String>('timestamp')),
            )
            case (final Rat rat, final DateTime at))
          _sighting(r, rat, at),
    ];
  }

  static CellSighting _sighting(QueryRow r, Rat rat, DateTime at) {
    final flags = (r.readNullable<String>('quality_flag') ?? '').split('|');
    final quality = r.readNullable<String>('gps_quality');
    final usable =
        !flags.contains(SampleQuality.mockLocation) &&
        quality != null &&
        quality != 'NONE';
    return CellSighting(
      measurementId: r.read<String>('measurement_id'),
      timestamp: at,
      isServing: r.read<bool>('is_serving'),
      rat: rat,
      lat: usable ? r.readNullable<double>('lat') : null,
      lon: usable ? r.readNullable<double>('lon') : null,
      goodFix: quality == 'GOOD',
      mcc: r.readNullable<String>('mcc'),
      mnc: r.readNullable<String>('mnc'),
      lacTac: r.readNullable<int>('lac_tac'),
      cellId: r.readNullable<int>('cell_id'),
      enbId: r.readNullable<int>('enb_id'),
      gnbId: r.readNullable<int>('gnb_id'),
      pci: r.readNullable<int>('pci_psc_bsic'),
      arfcn: r.readNullable<int>('arfcn'),
      band: r.readNullable<String>('band'),
      levelDbm: CellObservation.levelFor(
        rat,
        rsrpDbm: r.readNullable<double>('rsrp_dbm'),
        rscpDbm: r.readNullable<double>('rscp_dbm'),
        rssiDbm: r.readNullable<double>('rssi_dbm'),
      ),
      timingAdvance: r.readNullable<int>('timing_advance'),
    );
  }
}
