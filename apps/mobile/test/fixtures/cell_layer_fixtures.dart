import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

final testSite = EstimatedSite(
  key: 'LTE:537-03:enb84',
  rat: Rat.lte,
  lat: -9.4385,
  lon: 147.1810,
  uncertaintyM: 120,
  method: SiteMethod.timingAdvance,
  samples: 40,
  siteId: 84,
  cells: const [
    EstimatedCell(
      key: 'LTE:537-03:77',
      label: 'PCI 422 · cell 77',
      azimuthDeg: 45,
    ),
    EstimatedCell(key: 'LTE:537-03:78', label: 'PCI 423 · cell 78'),
  ],
);

final testCell = ScannedCell(
  key: 'LTE:537-03:77',
  siteKey: 'LTE:537-03:enb84',
  rat: Rat.lte,
  servingCount: 30,
  neighbourCount: 5,
  firstSeen: DateTime.utc(2026, 10, 21, 1),
  lastSeen: DateTime.utc(2026, 10, 21, 2),
  mcc: '537',
  mnc: '03',
  cellId: 77,
  siteId: 84,
  pci: 422,
  arfcn: 500,
  band: '1',
  bestLevelDbm: -71,
  meanLevelDbm: -88.4,
);

final testNeighbour = ScannedCell(
  key: 'LTE:a1300:p99',
  siteKey: 'LTE:a1300:p99',
  rat: Rat.lte,
  servingCount: 0,
  neighbourCount: 3,
  firstSeen: DateTime.utc(2026, 10, 21, 1),
  lastSeen: DateTime.utc(2026, 10, 21, 1, 5),
  pci: 99,
  arfcn: 1300,
  band: '3',
  bestLevelDbm: -101,
  meanLevelDbm: -104,
);

/// Samples pt(0..) in track_fixtures are served by [testSite].
CellLayer testLayer({Map<String, String>? serving}) => CellLayer(
  cells: [testCell, testNeighbour],
  sites: [testSite],
  servingSiteByMeasurement: serving ?? const {},
);
