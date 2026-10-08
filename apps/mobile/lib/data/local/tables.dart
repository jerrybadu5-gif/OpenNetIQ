import 'package:drift/drift.dart';

// Drift tables for local schema v1. Must match database/mobile/schema_v1.sql
// and docs/standards/DATA-DICTIONARY.md (verified by test/data/local/
// schema_test.dart). Ids are UUIDv7 text, times are UTC ISO 8601 text.

@DataClassName('DeviceRow')
class Devices extends Table {
  late final deviceId = text()();
  late final manufacturer = text()();
  late final model = text()();
  late final androidVersion = text()();
  late final apiLevel = integer()();
  late final chipset = text().nullable()();
  late final appVersion = text()();
  late final createdAt = text()();
  late final updatedAt = text()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

@DataClassName('SessionRow')
class Sessions extends Table {
  late final sessionId = text()();
  late final deviceId = text().references(Devices, #deviceId)();
  late final name = text()();
  late final Column<String> sessionType = text().check(
    sessionType.isIn(const ['drive', 'walk', 'static', 'single_test']),
  )();
  late final Column<String> status = text().check(
    status.isIn(const [
      'created',
      'recording',
      'paused',
      'completed',
      'aborted',
    ]),
  )();
  late final Column<int> samplingIntervalMs = integer().check(
    samplingIntervalMs.isIn(const [1000, 2000, 5000]),
  )();
  late final operatorUnderTest = text().nullable()();
  late final notes = text().nullable()();
  late final methodologyVersion = text()();
  late final startedAt = text().nullable()();
  late final endedAt = text().nullable()();
  late final sampleCount = integer().withDefault(const Constant(0))();
  late final distanceM = real().nullable()();
  late final Column<String> syncState = text()
      .withDefault(const Constant('local'))
      .check(syncState.isIn(const ['local', 'queued', 'synced', 'failed']))();
  late final version = integer().withDefault(const Constant(1))();
  late final createdAt = text()();
  late final updatedAt = text()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId};
}

@DataClassName('SampleRow')
@TableIndex(name: 'ix_samples_session_ts', columns: {#sessionId, #timestamp})
class Samples extends Table {
  late final measurementId = text()();
  late final sessionId = text().references(
    Sessions,
    #sessionId,
    onDelete: KeyAction.cascade,
  )();
  late final timestamp = text()();
  late final lat = real().nullable()();
  late final lon = real().nullable()();
  late final altitudeM = real().nullable()();
  late final speedMps = real().nullable()();
  late final bearingDeg = real().nullable()();
  late final hAccuracyM = real().nullable()();
  late final vAccuracyM = real().nullable()();
  late final satellitesUsed = integer().nullable()();
  late final Column<String> gpsQuality = text().nullable().check(
    gpsQuality.isIn(const ['GOOD', 'POOR', 'NONE']),
  )();
  late final operatorName = text().named('operator').nullable()();
  late final mcc = text().nullable()();
  late final mnc = text().nullable()();
  late final simOperator = text().nullable()();
  late final networkType = text()();
  late final dataState = text().nullable()();
  late final isRoaming = boolean().nullable()();
  late final radioTimestamp = text().nullable()();
  late final qualityFlag = text().nullable()();
  late final createdAt = text()();

  @override
  Set<Column<Object>> get primaryKey => {measurementId};
}

@DataClassName('CellObservationRow')
@TableIndex(name: 'ix_cells_measurement', columns: {#measurementId})
class CellObservations extends Table {
  late final observationId = text()();
  late final measurementId = text().references(
    Samples,
    #measurementId,
    onDelete: KeyAction.cascade,
  )();
  late final isServing = boolean()();
  late final Column<String> rat = text().check(
    rat.isIn(const ['GSM', 'WCDMA', 'LTE', 'NR', 'CDMA', 'TDSCDMA']),
  )();
  late final mcc = text().nullable()();
  late final mnc = text().nullable()();
  late final lacTac = integer().nullable()();
  late final cellId = integer().nullable()();
  late final enbId = integer().nullable()();
  late final gnbId = integer().nullable()();
  late final localCellId = integer().nullable()();
  late final pciPscBsic = integer().nullable()();
  late final arfcn = integer().nullable()();
  late final band = text().nullable()();
  late final bandwidthKhz = integer().nullable()();
  late final rssiDbm = real().nullable()();
  late final rscpDbm = real().nullable()();
  late final ecnoDb = real().nullable()();
  late final rsrpDbm = real().nullable()();
  late final rsrqDb = real().nullable()();
  late final sinrDb = real().nullable()();
  late final cqi = integer().nullable()();
  late final timingAdvance = integer().nullable()();
  late final csiRsrpDbm = real().nullable()();
  late final csiRsrqDb = real().nullable()();
  late final csiSinrDb = real().nullable()();
  late final qualityFlag = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {observationId};
}

@DataClassName('SpeedTestRow')
class SpeedTests extends Table {
  late final testId = text()();
  late final sessionId = text().nullable().references(
    Sessions,
    #sessionId,
    onDelete: KeyAction.cascade,
  )();
  late final measurementId = text().nullable().references(
    Samples,
    #measurementId,
  )();
  late final timestamp = text()();
  late final method = text()();
  late final methodologyVersion = text()();
  late final serverId = text()();
  late final serverHost = text()();
  late final streams = integer()();
  late final dnsMs = real().nullable()();
  late final tcpConnectMs = real().nullable()();
  late final dlMeanMbps = real().named('dl_mean_mbps').nullable()();
  late final dlMedianMbps = real().named('dl_median_mbps').nullable()();
  late final dlP10Mbps = real().named('dl_p10_mbps').nullable()();
  late final dlP90Mbps = real().named('dl_p90_mbps').nullable()();
  late final dlPeakMbps = real().named('dl_peak_mbps').nullable()();
  late final dlBytes = integer().nullable()();
  late final ulMeanMbps = real().named('ul_mean_mbps').nullable()();
  late final ulMedianMbps = real().named('ul_median_mbps').nullable()();
  late final ulP10Mbps = real().named('ul_p10_mbps').nullable()();
  late final ulP90Mbps = real().named('ul_p90_mbps').nullable()();
  late final ulPeakMbps = real().named('ul_peak_mbps').nullable()();
  late final ulBytes = integer().nullable()();
  late final ratChanged = boolean().withDefault(const Constant(false))();
  late final Column<String> status = text().check(
    status.isIn(const ['ok', 'partial', 'failed']),
  )();
  late final error = text().nullable()();
  late final createdAt = text()();

  @override
  Set<Column<Object>> get primaryKey => {testId};
}

@DataClassName('LatencyTestRow')
class LatencyTests extends Table {
  late final testId = text()();
  late final sessionId = text().nullable().references(
    Sessions,
    #sessionId,
    onDelete: KeyAction.cascade,
  )();
  late final measurementId = text().nullable().references(
    Samples,
    #measurementId,
  )();
  late final timestamp = text()();
  late final Column<String> protocol = text().check(
    protocol.isIn(const ['icmp', 'tcp', 'http', 'dns']),
  )();
  late final methodologyVersion = text()();
  late final target = text()();
  late final probesSent = integer()();
  late final probesReceived = integer()();
  late final minMs = real().nullable()();
  late final maxMs = real().nullable()();
  late final meanMs = real().nullable()();
  late final medianMs = real().nullable()();
  late final p95Ms = real().named('p95_ms').nullable()();
  late final jitterMs = real().nullable()();
  late final packetLossPct = real().nullable()();
  late final rawRttsMs = text().nullable()();
  late final Column<String> status = text().check(
    status.isIn(const ['ok', 'partial', 'failed']),
  )();
  late final createdAt = text()();

  @override
  Set<Column<Object>> get primaryKey => {testId};
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  late final settingKey = text().named('key')();
  late final settingValue = text().named('value')();
  late final updatedAt = text()();

  @override
  Set<Column<Object>> get primaryKey => {settingKey};
}

@DataClassName('ConsentRow')
class ConsentLog extends Table {
  late final consentId = text()();
  late final Column<String> scope = text().check(
    scope.isIn(const ['location', 'radio', 'background_location', 'upload']),
  )();
  late final granted = boolean()();
  late final policyVersion = text()();
  late final timestamp = text()();

  @override
  Set<Column<Object>> get primaryKey => {consentId};
}
