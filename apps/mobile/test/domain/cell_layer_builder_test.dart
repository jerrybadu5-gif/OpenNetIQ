import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/services/cell_layer_builder.dart';

const siteLat = -9.44;
const siteLon = 147.18;
const mPerDegLat = 111195.08;
final mPerDegLon = mPerDegLat * math.cos(siteLat * math.pi / 180);

(double, double) offset(double eastM, double northM) =>
    (siteLat + northM / mPerDegLat, siteLon + eastM / mPerDegLon);

double distanceM(double lat, double lon) {
  final dy = (lat - siteLat) * mPerDegLat;
  final dx = (lon - siteLon) * mPerDegLon;
  return math.sqrt(dx * dx + dy * dy);
}

/// Road positions (metres from the site): an L-shaped drive.
List<(double, double)> lRoad() => [
  for (var x = -1500.0; x <= 1200; x += 50) (x, -900.0),
  for (var y = -850.0; y <= 1000; y += 50) (1200.0, y),
];

var _n = 0;

CellSighting sighting(
  double east,
  double north, {
  bool serving = true,
  bool withTa = true,
  int cellId = 77,
  int pci = 422,
  int enb = 84,
  double? boresightDeg,
  bool identified = true,
  Rat rat = Rat.lte,
}) {
  final d = math.sqrt(east * east + north * north);
  var level = -50 - 35 * math.log(math.max(d, 50) / 50) / math.ln10;
  if (boresightDeg != null) {
    final bearing = (math.atan2(east, north) * 180 / math.pi + 360) % 360;
    var diff = (bearing - boresightDeg).abs() % 360;
    if (diff > 180) diff = 360 - diff;
    level -= 20 * math.min(1, diff / 90);
  }
  final (lat, lon) = offset(east, north);
  return CellSighting(
    measurementId: 'm${_n++}',
    timestamp: DateTime.utc(2026, 10, 21).add(Duration(seconds: _n)),
    isServing: serving,
    rat: rat,
    lat: lat,
    lon: lon,
    goodFix: true,
    mcc: '537',
    mnc: '03',
    lacTac: 110,
    cellId: identified ? cellId : null,
    enbId: identified ? enb : null,
    pci: pci,
    arfcn: 500,
    band: '1',
    levelDbm: level,
    timingAdvance: withTa && serving
        ? (d / SiteEstimator.taStepM).floor()
        : null,
  );
}

void main() {
  test('timing advance on an L-shaped drive finds the site within 150 m', () {
    final layer = CellLayerBuilder.build([
      for (final (x, y) in lRoad()) sighting(x, y),
    ]);
    final site = layer.sites.single;
    expect(site.method, SiteMethod.timingAdvance);
    expect(distanceM(site.lat, site.lon), lessThan(150));
    expect(site.uncertaintyM, greaterThanOrEqualTo(80));
    expect(site.label, 'eNB 84');
  });

  test('straight road is ambiguous: falls back to strongest samples', () {
    final layer = CellLayerBuilder.build([
      for (var x = -1500.0; x <= 1500; x += 50) sighting(x, -400),
    ]);
    final site = layer.sites.single;
    expect(site.method, SiteMethod.levelCentroid);
    // Centroid sits on the road nearest the site; uncertainty covers it.
    expect(distanceM(site.lat, site.lon), lessThan(site.uncertaintyM + 50));
  });

  test('no timing advance: level centroid', () {
    final layer = CellLayerBuilder.build([
      for (final (x, y) in lRoad()) sighting(x, y, withTa: false),
    ]);
    final site = layer.sites.single;
    expect(site.method, SiteMethod.levelCentroid);
    expect(site.uncertaintyM, greaterThanOrEqualTo(200));
  });

  test('sectors of one eNB share a site; azimuths follow the beams', () {
    final road = [
      for (var a = 0; a < 360; a += 5)
        (600 * math.sin(a * math.pi / 180), 600 * math.cos(a * math.pi / 180)),
    ];
    final list = <CellSighting>[
      for (final (x, y) in road) ...[
        sighting(x, y, cellId: 1, pci: 10, boresightDeg: 0),
        sighting(x, y, cellId: 2, pci: 11, boresightDeg: 120, serving: false),
        sighting(x, y, cellId: 3, pci: 12, boresightDeg: 240, serving: false),
      ],
    ];
    final layer = CellLayerBuilder.build(list);
    final site = layer.sites.single;
    expect(site.cells, hasLength(3));
    expect(distanceM(site.lat, site.lon), lessThan(150));
    double angleDiff(double a, double b) {
      final d = (a - b).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    final az = {for (final c in site.cells) c.label: c.azimuthDeg};
    expect(angleDiff(az['PCI 10 · cell 1']!, 0), lessThan(30));
    expect(angleDiff(az['PCI 11 · cell 2']!, 120), lessThan(30));
    expect(angleDiff(az['PCI 12 · cell 3']!, 240), lessThan(30));
  });

  test('scan aggregates cells and resolves unidentified neighbours', () {
    final list = [
      sighting(100, 100, cellId: 5, pci: 30),
      sighting(110, 100, cellId: 5, pci: 30),
      sighting(120, 100, serving: false, identified: false, pci: 30),
      sighting(130, 100, serving: false, identified: false, pci: 99),
    ];
    final layer = CellLayerBuilder.build(list);
    final cell5 = layer.cells.firstWhere((c) => c.cellId == 5);
    expect(cell5.servingCount, 2);
    expect(cell5.neighbourCount, 1);
    expect(cell5.bestLevelDbm, isNotNull);
    expect(cell5.siteId, 84);
    expect(cell5.bandLabel, 'LTE · B1 · EARFCN 500');
    final unknown = layer.cells.firstWhere((c) => c.pci == 99);
    expect(unknown.cellId, isNull);
    expect(unknown.key, 'LTE:a500:p99');
    expect(
      layer.servingSiteByMeasurement[list.first.measurementId],
      'LTE:537-03:enb84',
    );
    expect(layer.site('LTE:537-03:enb84'), isNotNull);
    expect(layer.site('nope'), isNull);
  });

  test('NSA: LTE anchor is the primary serving site', () {
    final nr = CellSighting(
      measurementId: 'x',
      timestamp: DateTime.utc(2026),
      isServing: true,
      rat: Rat.nr,
      cellId: 9,
      gnbId: 7,
      mcc: '537',
      mnc: '03',
    );
    final lte = CellSighting(
      measurementId: 'x',
      timestamp: DateTime.utc(2026),
      isServing: true,
      rat: Rat.lte,
      cellId: 1,
      enbId: 2,
      mcc: '537',
      mnc: '03',
    );
    final layer = CellLayerBuilder.build([nr, lte]);
    expect(layer.servingSiteByMeasurement['x'], 'LTE:537-03:enb2');
    expect(layer.sites, isEmpty); // no fixes
    expect(nr.siteKey, 'NR:537-03:gnb7');
    expect(CellLayer.empty.cells, isEmpty);
  });

  test(
    'inconsistent or extreme timing advance never yields wild positions',
    () {
      final rnd = math.Random(7);
      // Near-collinear drive with noisy and partly absurd TA values.
      final list = [
        for (var x = -800.0; x <= 800; x += 40)
          CellSighting(
            measurementId: 'n${x.round()}',
            timestamp: DateTime.utc(
              2026,
              10,
              25,
            ).add(Duration(seconds: x.round() + 900)),
            isServing: true,
            rat: Rat.lte,
            lat: offset(x, 300 + rnd.nextDouble()).$1,
            lon: offset(x, 300).$2,
            goodFix: true,
            mcc: '537',
            mnc: '03',
            cellId: 1,
            enbId: 9,
            pci: 1,
            levelDbm: -80 - rnd.nextDouble() * 20,
            timingAdvance: rnd.nextBool() ? rnd.nextInt(1283) : rnd.nextInt(20),
          ),
      ];
      final site = CellLayerBuilder.build(list).sites.single;
      expect(site.lat.abs(), lessThanOrEqualTo(90));
      expect(site.lon.abs(), lessThanOrEqualTo(180));
      expect(distanceM(site.lat, site.lon), lessThan(5000));
    },
  );

  test('all sightings at one spot with TA: no crash, centroid', () {
    final list = [for (var i = 0; i < 10; i++) sighting(100, 100, cellId: 2)];
    final site = CellLayerBuilder.build(list).sites.single;
    expect(site.method, SiteMethod.levelCentroid);
    expect(distanceM(site.lat, site.lon), lessThan(200));
  });
}
