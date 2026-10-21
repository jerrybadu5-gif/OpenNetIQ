import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// One stored cell observation joined with its sample (issue #27).
/// Input of the cell scan and the site estimator.
class CellSighting {
  const CellSighting({
    required this.measurementId,
    required this.timestamp,
    required this.isServing,
    required this.rat,
    this.lat,
    this.lon,
    this.goodFix = false,
    this.mcc,
    this.mnc,
    this.lacTac,
    this.cellId,
    this.enbId,
    this.gnbId,
    this.pci,
    this.arfcn,
    this.band,
    this.levelDbm,
    this.timingAdvance,
  });

  final String measurementId;
  final DateTime timestamp;
  final bool isServing;
  final Rat rat;

  /// Usable fix of the sample (null without fix or for mock locations).
  final double? lat;
  final double? lon;

  /// GNSS quality GOOD (POOR fixes are used only when nothing better exists).
  final bool goodFix;
  final String? mcc;
  final String? mnc;
  final int? lacTac;
  final int? cellId;
  final int? enbId;
  final int? gnbId;
  final int? pci;
  final int? arfcn;
  final String? band;

  /// RSRP / SS-RSRP / RSCP / RSSI (CellObservation.levelFor).
  final double? levelDbm;

  /// LTE timing advance index as reported by Android (serving cell only).
  final int? timingAdvance;

  bool get hasFix => lat != null && lon != null;

  /// Full identity known (serving cells, some neighbours).
  bool get identified => cellId != null;

  /// Stable key: global identity when known, else RAT + ARFCN + PCI.
  String get cellKey => identified
      ? '${rat.wireValue}:${mcc ?? '?'}-${mnc ?? '?'}:$cellId'
      : '${rat.wireValue}:a${arfcn ?? '?'}:p${pci ?? '?'}';

  /// Radio-channel key used to match unidentified neighbours to cells.
  String get channelKey => '${rat.wireValue}:a${arfcn ?? '?'}:p${pci ?? '?'}';

  /// Site (eNB / gNB) key: cells of one site share it; otherwise the cell.
  String get siteKey => switch (rat) {
    Rat.lte when enbId != null => 'LTE:${mcc ?? '?'}-${mnc ?? '?'}:enb$enbId',
    Rat.nr when gnbId != null => 'NR:${mcc ?? '?'}-${mnc ?? '?'}:gnb$gnbId',
    _ => cellKey,
  };
}

/// One cell in the scan, aggregated over all its sightings.
class ScannedCell {
  const ScannedCell({
    required this.key,
    required this.siteKey,
    required this.rat,
    required this.servingCount,
    required this.neighbourCount,
    required this.firstSeen,
    required this.lastSeen,
    this.mcc,
    this.mnc,
    this.lacTac,
    this.cellId,
    this.siteId,
    this.pci,
    this.arfcn,
    this.band,
    this.bestLevelDbm,
    this.meanLevelDbm,
  });

  final String key;
  final String siteKey;
  final Rat rat;
  final int servingCount;
  final int neighbourCount;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? mcc;
  final String? mnc;
  final int? lacTac;
  final int? cellId;

  /// eNB ID (LTE) or gNB ID (NR).
  final int? siteId;
  final int? pci;
  final int? arfcn;
  final String? band;
  final double? bestLevelDbm;

  /// Mean of dBm values (log domain), as G-NetTrack and most tools report.
  final double? meanLevelDbm;

  int get sightings => servingCount + neighbourCount;

  /// e.g. "LTE B1 · EARFCN 500" for grouping.
  String get bandLabel {
    final b = band;
    final channel = switch (rat) {
      Rat.lte => 'EARFCN',
      Rat.nr => 'NR-ARFCN',
      Rat.wcdma => 'UARFCN',
      Rat.gsm => 'ARFCN',
      _ => 'ARFCN',
    };
    return [
      rat.wireValue,
      if (b != null && b.isNotEmpty) 'B$b',
      if (arfcn != null) '$channel $arfcn',
    ].join(' · ');
  }
}

enum SiteMethod {
  /// Least-squares fit to timing-advance ranges (LTE).
  timingAdvance('timing_advance', 'Timing advance'),

  /// Level-weighted centroid of the strongest samples (biased to the road).
  levelCentroid('level_centroid', 'Strongest samples');

  const SiteMethod(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

/// Estimated position of one site from drive data (never surveyed truth).
class EstimatedSite {
  const EstimatedSite({
    required this.key,
    required this.rat,
    required this.lat,
    required this.lon,
    required this.uncertaintyM,
    required this.method,
    required this.samples,
    required this.cells,
    this.mcc,
    this.mnc,
    this.siteId,
  });

  final String key;
  final Rat rat;
  final double lat;
  final double lon;

  /// Radius (m) that likely contains the true site.
  final double uncertaintyM;
  final SiteMethod method;

  /// Located sightings used.
  final int samples;
  final List<EstimatedCell> cells;
  final String? mcc;
  final String? mnc;
  final int? siteId;

  String get label {
    final id = siteId;
    final prefix = switch (rat) {
      Rat.lte => 'eNB',
      Rat.nr => 'gNB',
      _ => rat.wireValue,
    };
    return id == null ? '$prefix ${cells.first.label}' : '$prefix $id';
  }
}

class EstimatedCell {
  const EstimatedCell({
    required this.key,
    required this.label,
    this.azimuthDeg,
  });

  final String key;

  /// e.g. "PCI 422 · cell 77".
  final String label;

  /// Estimated main-lobe direction (degrees from north), null if unclear.
  final double? azimuthDeg;
}

/// Cell scan plus estimated sites for a set of sightings.
class CellLayer {
  const CellLayer({
    required this.cells,
    required this.sites,
    required this.servingSiteByMeasurement,
  });

  static const empty = CellLayer(
    cells: [],
    sites: [],
    servingSiteByMeasurement: {},
  );

  final List<ScannedCell> cells;
  final List<EstimatedSite> sites;

  /// measurement_id -> site key of its primary serving cell.
  final Map<String, String> servingSiteByMeasurement;

  EstimatedSite? site(String key) {
    for (final s in sites) {
      if (s.key == key) return s;
    }
    return null;
  }
}
