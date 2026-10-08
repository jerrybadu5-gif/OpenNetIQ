import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// One serving or neighbour cell (`cell_observations`, DATA-DICTIONARY.md).
/// Null means unavailable or not applicable to the RAT, never zero.
class CellObservation {
  const CellObservation({
    required this.isServing,
    required this.rat,
    this.mcc,
    this.mnc,
    this.lacTac,
    this.cellId,
    this.enbId,
    this.gnbId,
    this.localCellId,
    this.pciPscBsic,
    this.arfcn,
    this.band,
    this.bandwidthKhz,
    this.rssiDbm,
    this.rscpDbm,
    this.ecnoDb,
    this.rsrpDbm,
    this.rsrqDb,
    this.sinrDb,
    this.cqi,
    this.timingAdvance,
    this.csiRsrpDbm,
    this.csiRsrqDb,
    this.csiSinrDb,
    this.qualityFlag,
  });

  final bool isServing;
  final Rat rat;
  final String? mcc;
  final String? mnc;
  final int? lacTac;
  final int? cellId;
  final int? enbId;
  final int? gnbId;
  final int? localCellId;
  final int? pciPscBsic;
  final int? arfcn;
  final String? band;
  final int? bandwidthKhz;
  final double? rssiDbm;
  final double? rscpDbm;
  final double? ecnoDb;
  final double? rsrpDbm;
  final double? rsrqDb;
  final double? sinrDb;
  final int? cqi;
  final int? timingAdvance;
  final double? csiRsrpDbm;
  final double? csiRsrqDb;
  final double? csiSinrDb;
  final String? qualityFlag;

  /// Main level metric for the RAT: RSRP (LTE), SS-RSRP (NR), RSCP (WCDMA),
  /// RSSI (GSM).
  double? get levelDbm => switch (rat) {
    Rat.lte || Rat.nr => rsrpDbm,
    Rat.wcdma => rscpDbm,
    Rat.gsm => rssiDbm,
    _ => rsrpDbm ?? rssiDbm,
  };

  String get levelLabel => switch (rat) {
    Rat.lte => 'RSRP',
    Rat.nr => 'SS-RSRP',
    Rat.wcdma => 'RSCP',
    Rat.gsm => 'RSSI',
    _ => 'Level',
  };

  /// Label of [pciPscBsic] for the RAT.
  String get physicalIdLabel => switch (rat) {
    Rat.lte || Rat.nr => 'PCI',
    Rat.wcdma => 'PSC',
    Rat.gsm => 'BSIC',
    _ => 'ID',
  };

  /// Label of [arfcn] for the RAT.
  String get channelLabel => switch (rat) {
    Rat.lte => 'EARFCN',
    Rat.nr => 'NR-ARFCN',
    Rat.wcdma => 'UARFCN',
    _ => 'ARFCN',
  };

  /// Label of [lacTac] for the RAT.
  String get areaLabel => switch (rat) {
    Rat.lte || Rat.nr => 'TAC',
    _ => 'LAC',
  };
}
