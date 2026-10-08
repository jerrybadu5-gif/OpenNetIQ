import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/mappers/channel_reader.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// Maps platform-channel payloads (snake_case) to domain entities.
abstract final class RadioSnapshotMapper {
  static RadioSnapshot fromChannel(Object? event) {
    final r = ChannelReader(event, 'radio snapshot');
    final timestamp = parseUtc(r.requireString('timestamp'));
    if (timestamp == null) {
      throw const FormatException('Invalid "timestamp": expected UTC ISO 8601');
    }
    final cells = <CellObservation>[];
    for (final raw in r.list('cells')) {
      final cell = cellFromChannel(raw);
      if (cell != null) cells.add(cell);
    }
    return RadioSnapshot(
      timestamp: timestamp,
      radioTimestamp: parseUtc(r.string('radio_timestamp')),
      operatorName: r.string('operator'),
      mcc: r.string('mcc'),
      mnc: r.string('mnc'),
      simOperator: r.string('sim_operator'),
      networkType:
          NetworkType.fromWire(r.string('network_type')) ?? NetworkType.unknown,
      dataState: r.string('data_state'),
      isRoaming: r.boolean('is_roaming'),
      qualityFlag: r.string('quality_flag'),
      cells: List.unmodifiable(cells),
    );
  }

  /// Returns null for RATs this app version does not know (forward compatible).
  static CellObservation? cellFromChannel(Object? raw) {
    final r = ChannelReader(raw, 'cell observation');
    final rat = Rat.fromWire(r.requireString('rat'));
    if (rat == null) return null;
    return CellObservation(
      isServing: r.requireBool('is_serving'),
      rat: rat,
      mcc: r.string('mcc'),
      mnc: r.string('mnc'),
      lacTac: r.integer('lac_tac'),
      cellId: r.integer('cell_id'),
      enbId: r.integer('enb_id'),
      gnbId: r.integer('gnb_id'),
      localCellId: r.integer('local_cell_id'),
      pciPscBsic: r.integer('pci_psc_bsic'),
      arfcn: r.integer('arfcn'),
      band: r.string('band'),
      bandwidthKhz: r.integer('bandwidth_khz'),
      rssiDbm: r.decimal('rssi_dbm'),
      rscpDbm: r.decimal('rscp_dbm'),
      ecnoDb: r.decimal('ecno_db'),
      rsrpDbm: r.decimal('rsrp_dbm'),
      rsrqDb: r.decimal('rsrq_db'),
      sinrDb: r.decimal('sinr_db'),
      cqi: r.integer('cqi'),
      timingAdvance: r.integer('timing_advance'),
      csiRsrpDbm: r.decimal('csi_rsrp_dbm'),
      csiRsrqDb: r.decimal('csi_rsrq_db'),
      csiSinrDb: r.decimal('csi_sinr_db'),
      qualityFlag: r.string('quality_flag'),
    );
  }

  static RadioPermissions permissionsFromChannel(Object? raw) {
    final r = ChannelReader(raw, 'permission status');
    return RadioPermissions(
      location: r.boolean('location') ?? false,
      phoneState: r.boolean('phone_state') ?? false,
      hasTelephony: r.boolean('has_telephony') ?? false,
      apiLevel: r.integer('api_level'),
    );
  }
}
