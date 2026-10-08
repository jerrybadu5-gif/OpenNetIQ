import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/services/sample_quality.dart';

/// Rows for one sampling tick, built without touching the database.
class SampleRows {
  const SampleRows({required this.sample, required this.cells, this.fix});

  final SamplesCompanion sample;
  final List<CellObservationsCompanion> cells;

  /// Fix used to geotag the sample (null when none was usable).
  final LocationFix? fix;
}

/// Maps a radio snapshot and the location status of the same tick to
/// `samples` + `cell_observations` rows (DATA-DICTIONARY.md).
SampleRows buildSampleRows({
  required String sessionId,
  required String measurementId,
  required DateTime createdAt,
  required RadioSnapshot radio,
  required LocationStatus? location,
  required String Function() newId,
}) {
  final fix = SampleQuality.usableFix(radio, location);
  final sample = SamplesCompanion.insert(
    measurementId: measurementId,
    sessionId: sessionId,
    timestamp: formatUtc(radio.timestamp),
    networkType: radio.networkType.wireValue,
    createdAt: formatUtc(createdAt),
    lat: Value(fix?.lat),
    lon: Value(fix?.lon),
    altitudeM: Value(fix?.altitudeM),
    speedMps: Value(fix?.speedMps),
    bearingDeg: Value(fix?.bearingDeg),
    hAccuracyM: Value(fix?.hAccuracyM),
    vAccuracyM: Value(fix?.vAccuracyM),
    satellitesUsed: Value(fix == null ? null : location?.satellitesUsed),
    gpsQuality: Value(
      fix == null ? GpsQuality.none.wireValue : location!.quality.wireValue,
    ),
    operatorName: Value(radio.operatorName),
    mcc: Value(radio.mcc),
    mnc: Value(radio.mnc),
    simOperator: Value(radio.simOperator),
    dataState: Value(radio.dataState),
    isRoaming: Value(radio.isRoaming),
    radioTimestamp: Value(
      radio.radioTimestamp == null ? null : formatUtc(radio.radioTimestamp!),
    ),
    qualityFlag: Value(SampleQuality.mergeFlags(radio, fix)),
  );
  return SampleRows(
    sample: sample,
    cells: [
      for (final cell in radio.cells) cellRow(cell, measurementId, newId()),
    ],
    fix: fix,
  );
}

CellObservationsCompanion cellRow(
  CellObservation c,
  String measurementId,
  String observationId,
) => CellObservationsCompanion.insert(
  observationId: observationId,
  measurementId: measurementId,
  isServing: c.isServing,
  rat: c.rat.wireValue,
  mcc: Value(c.mcc),
  mnc: Value(c.mnc),
  lacTac: Value(c.lacTac),
  cellId: Value(c.cellId),
  enbId: Value(c.enbId),
  gnbId: Value(c.gnbId),
  localCellId: Value(c.localCellId),
  pciPscBsic: Value(c.pciPscBsic),
  arfcn: Value(c.arfcn),
  band: Value(c.band),
  bandwidthKhz: Value(c.bandwidthKhz),
  rssiDbm: Value(c.rssiDbm),
  rscpDbm: Value(c.rscpDbm),
  ecnoDb: Value(c.ecnoDb),
  rsrpDbm: Value(c.rsrpDbm),
  rsrqDb: Value(c.rsrqDb),
  sinrDb: Value(c.sinrDb),
  cqi: Value(c.cqi),
  timingAdvance: Value(c.timingAdvance),
  csiRsrpDbm: Value(c.csiRsrpDbm),
  csiRsrqDb: Value(c.csiRsrqDb),
  csiSinrDb: Value(c.csiSinrDb),
  qualityFlag: Value(c.qualityFlag),
);
