import 'dart:math' as math;

import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// Builds the cell scan and estimated site layer from stored sightings
/// (issue #27, MEASUREMENT-METHODOLOGY.md §9).
abstract final class CellLayerBuilder {
  static CellLayer build(List<CellSighting> sightings) {
    final resolved = _resolveNeighbours(sightings);
    final byCell = <String, List<CellSighting>>{};
    for (final s in resolved) {
      (byCell[s.cellKey] ??= []).add(s);
    }
    final cells = [for (final e in byCell.entries) _aggregate(e.key, e.value)]
      ..sort((a, b) {
        final band = a.bandLabel.compareTo(b.bandLabel);
        return band != 0
            ? band
            : (b.bestLevelDbm ?? -999).compareTo(a.bestLevelDbm ?? -999);
      });

    final bySite = <String, List<CellSighting>>{};
    for (final s in resolved) {
      if (s.identified && s.hasFix) (bySite[s.siteKey] ??= []).add(s);
    }
    final sites = <EstimatedSite>[
      for (final e in bySite.entries) ?SiteEstimator.estimate(e.key, e.value),
    ];

    return CellLayer(
      cells: cells,
      sites: sites,
      servingSiteByMeasurement: _primaryServing(resolved),
    );
  }

  /// Gives unidentified neighbours (ARFCN + PCI only) the identity of the
  /// one identified cell on the same channel, when it is unambiguous.
  static List<CellSighting> _resolveNeighbours(List<CellSighting> input) {
    final byChannel = <String, Map<String, CellSighting>>{};
    for (final s in input) {
      if (s.identified && s.pci != null && s.arfcn != null) {
        (byChannel[s.channelKey] ??= {})[s.cellKey] = s;
      }
    }
    return [
      for (final s in input)
        if (!s.identified && byChannel[s.channelKey]?.length == 1)
          _withIdentity(s, byChannel[s.channelKey]!.values.first)
        else
          s,
    ];
  }

  static CellSighting _withIdentity(CellSighting s, CellSighting id) =>
      CellSighting(
        measurementId: s.measurementId,
        timestamp: s.timestamp,
        isServing: s.isServing,
        rat: s.rat,
        lat: s.lat,
        lon: s.lon,
        goodFix: s.goodFix,
        mcc: id.mcc,
        mnc: id.mnc,
        lacTac: id.lacTac,
        cellId: id.cellId,
        enbId: id.enbId,
        gnbId: id.gnbId,
        pci: s.pci,
        arfcn: s.arfcn,
        band: s.band ?? id.band,
        levelDbm: s.levelDbm,
        timingAdvance: s.timingAdvance,
      );

  static ScannedCell _aggregate(String key, List<CellSighting> list) {
    var serving = 0;
    double? best;
    var sum = 0.0;
    var n = 0;
    var first = list.first.timestamp;
    var last = list.first.timestamp;
    CellSighting ref = list.first;
    for (final s in list) {
      if (s.isServing) serving++;
      if (s.identified && !ref.identified) ref = s;
      final l = s.levelDbm;
      if (l != null) {
        best = best == null ? l : math.max(best, l);
        sum += l;
        n++;
      }
      if (s.timestamp.isBefore(first)) first = s.timestamp;
      if (s.timestamp.isAfter(last)) last = s.timestamp;
    }
    return ScannedCell(
      key: key,
      siteKey: ref.siteKey,
      rat: ref.rat,
      servingCount: serving,
      neighbourCount: list.length - serving,
      firstSeen: first,
      lastSeen: last,
      mcc: ref.mcc,
      mnc: ref.mnc,
      lacTac: ref.lacTac,
      cellId: ref.cellId,
      siteId: ref.rat == Rat.nr ? ref.gnbId : ref.enbId,
      pci: ref.pci,
      arfcn: ref.arfcn,
      band: ref.band,
      bestLevelDbm: best,
      meanLevelDbm: n == 0 ? null : sum / n,
    );
  }

  /// Same rule as the session map: LTE anchor first (5G NSA), else the first
  /// serving cell of the sample.
  static Map<String, String> _primaryServing(List<CellSighting> list) {
    final result = <String, String>{};
    final lte = <String>{};
    for (final s in list) {
      if (!s.isServing || !s.identified) continue;
      final known = result.containsKey(s.measurementId);
      if (!known || (s.rat == Rat.lte && !lte.contains(s.measurementId))) {
        result[s.measurementId] = s.siteKey;
        if (s.rat == Rat.lte) lte.add(s.measurementId);
      }
    }
    return result;
  }
}

/// Site position from drive data. Prefers LTE timing-advance ranges
/// (3GPP TS 36.213: one TA step = 16 Ts ≈ 78.12 m one way), falls back to
/// the level-weighted centroid of the strongest samples.
abstract final class SiteEstimator {
  static const double taStepM = 78.12;
  static const int maxTa = 1282;
  static const double _earthR = 6371008.8;

  static EstimatedSite? estimate(String key, List<CellSighting> sightings) {
    if (sightings.isEmpty) return null;
    final good = sightings.where((s) => s.goodFix).toList();
    final used = good.length >= 3 ? good : sightings;
    final origin = _Origin.of(used);
    final ref = used.firstWhere((s) => s.identified, orElse: () => used.first);

    final centroid = _levelCentroid(used, origin);
    var position = centroid.$1;
    var uncertainty = centroid.$2;
    var method = SiteMethod.levelCentroid;
    final ta = _timingAdvanceFit(used, origin, position);
    if (ta != null) {
      position = ta.$1;
      uncertainty = ta.$2;
      method = SiteMethod.timingAdvance;
    }

    final byCell = <String, List<CellSighting>>{};
    for (final s in used) {
      (byCell[s.cellKey] ??= []).add(s);
    }
    final cells = [
      for (final e in byCell.entries)
        EstimatedCell(
          key: e.key,
          label: _cellLabel(e.value.first),
          azimuthDeg: _azimuth(e.value, origin, position, uncertainty),
        ),
    ]..sort((a, b) => a.label.compareTo(b.label));
    final latLon = origin.toLatLon(position);
    return EstimatedSite(
      key: key,
      rat: ref.rat,
      lat: latLon.$1,
      lon: latLon.$2,
      uncertaintyM: uncertainty,
      method: method,
      samples: used.length,
      cells: cells,
      mcc: ref.mcc,
      mnc: ref.mnc,
      siteId: ref.rat == Rat.nr ? ref.gnbId : ref.enbId,
    );
  }

  static String _cellLabel(CellSighting s) => [
    if (s.pci != null) 'PCI ${s.pci}',
    if (s.cellId != null) 'cell ${s.cellId}',
    if (s.pci == null && s.arfcn != null) 'ARFCN ${s.arfcn}',
  ].join(' · ');

  static List<CellSighting> _strongest(List<CellSighting> list) {
    final withLevel = list.where((s) => s.levelDbm != null).toList()
      ..sort((a, b) => b.levelDbm!.compareTo(a.levelDbm!));
    if (withLevel.isEmpty) return list;
    final n = math.max(3, (withLevel.length / 4).ceil());
    return withLevel.take(n).toList();
  }

  static double _weight(CellSighting s, double maxLevel) => s.levelDbm == null
      ? 1
      : math.pow(10, (s.levelDbm! - maxLevel) / 10).toDouble();

  /// Level-weighted centroid of the strongest quarter (>= 3) of samples.
  /// Uncertainty: twice their weighted spread, at least 200 m (the site is
  /// usually off the road, the samples are on it).
  static (_Xy, double) _levelCentroid(List<CellSighting> list, _Origin o) {
    final top = _strongest(list);
    final maxLevel = top.first.levelDbm ?? 0;
    var wx = 0.0, wy = 0.0, w = 0.0;
    for (final s in top) {
      final p = o.toXy(s);
      final k = _weight(s, maxLevel);
      wx += p.x * k;
      wy += p.y * k;
      w += k;
    }
    final c = _Xy(wx / w, wy / w);
    var spread = 0.0;
    for (final s in top) {
      spread += _weight(s, maxLevel) * c.distSq(o.toXy(s));
    }
    return (c, math.max(200, 2 * math.sqrt(spread / w)));
  }

  /// Gauss-Newton fit of |p - x_i| = r_i over TA ranges from several start
  /// points. Null when there are fewer than 3 distinct positions, too little
  /// geometric spread, or a mirror solution fits about as well (straight
  /// road: the side of the road cannot be told).
  static (_Xy, double)? _timingAdvanceFit(
    List<CellSighting> list,
    _Origin o,
    _Xy start,
  ) {
    final ranged = <(_Xy, double)>[];
    final seen = <String>{};
    for (final s in list) {
      final ta = s.timingAdvance;
      if (!s.isServing || s.rat != Rat.lte || ta == null) continue;
      if (ta < 0 || ta > maxTa) continue;
      final p = o.toXy(s);
      final cell = '${(p.x / 10).round()}:${(p.y / 10).round()}:$ta';
      if (seen.add(cell)) ranged.add((p, (ta + 0.5) * taStepM));
    }
    if (ranged.length < 3) return null;
    var spread = 0.0;
    for (final a in ranged) {
      for (final b in ranged) {
        spread = math.max(spread, a.$1.distSq(b.$1));
      }
    }
    if (math.sqrt(spread) < 150) return null;

    final ranges = [for (final r in ranged) r.$2]..sort();
    final radius = math.max(100.0, ranges[ranges.length ~/ 2]);
    final starts = [
      start,
      for (var k = 0; k < 8; k++)
        _Xy(
          start.x + radius * math.cos(k * math.pi / 4),
          start.y + radius * math.sin(k * math.pi / 4),
        ),
    ];
    final fits = [for (final s in starts) _gaussNewton(ranged, s)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final best = fits.first;
    for (final f in fits.skip(1)) {
      if (f.$1.distSq(best.$1) > 200 * 200 && f.$2 < best.$2 * 1.5 + 1) {
        return null; // ambiguous mirror solution
      }
    }
    final rms = math.sqrt(best.$2 / ranged.length);
    return (best.$1, math.max(80, 2 * rms + taStepM / 2));
  }

  static (_Xy, double) _gaussNewton(List<(_Xy, double)> ranged, _Xy start) {
    var p = start;
    for (var iter = 0; iter < 30; iter++) {
      var a11 = 0.0, a12 = 0.0, a22 = 0.0, b1 = 0.0, b2 = 0.0;
      for (final (x, r) in ranged) {
        final dx = p.x - x.x, dy = p.y - x.y;
        final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        final jx = dx / d, jy = dy / d, res = d - r;
        a11 += jx * jx;
        a12 += jx * jy;
        a22 += jy * jy;
        b1 += jx * res;
        b2 += jy * res;
      }
      final det = a11 * a22 - a12 * a12;
      if (det.abs() < 1e-9) break;
      final sx = (a22 * b1 - a12 * b2) / det;
      final sy = (a11 * b2 - a12 * b1) / det;
      p = _Xy(p.x - sx, p.y - sy);
      if (sx * sx + sy * sy < 0.01) break;
    }
    var cost = 0.0;
    for (final (x, r) in ranged) {
      final res = math.sqrt(p.distSq(x)) - r;
      cost += res * res;
    }
    return (p, cost);
  }

  /// Direction from the site to the cell's strongest samples, when they
  /// agree (mean resultant length >= 0.5) and are outside the uncertainty.
  static double? _azimuth(
    List<CellSighting> list,
    _Origin o,
    _Xy site,
    double uncertainty,
  ) {
    final top = _strongest(list.where((s) => s.levelDbm != null).toList());
    if (top.length < 3) return null;
    final maxLevel = top.first.levelDbm!;
    var sx = 0.0, sy = 0.0, w = 0.0, far = 0;
    for (final s in top) {
      final p = o.toXy(s);
      final dx = p.x - site.x, dy = p.y - site.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1) continue;
      if (d > uncertainty / 2) far++;
      final k = _weight(s, maxLevel);
      sx += k * dx / d;
      sy += k * dy / d;
      w += k;
    }
    if (w == 0 || far < top.length / 2) return null;
    if (math.sqrt(sx * sx + sy * sy) / w < 0.5) return null;
    final deg = math.atan2(sx, sy) * 180 / math.pi; // from north, clockwise
    return (deg + 360) % 360;
  }
}

class _Xy {
  const _Xy(this.x, this.y);

  /// Metres east / north of the origin.
  final double x;
  final double y;

  double distSq(_Xy o) => (x - o.x) * (x - o.x) + (y - o.y) * (y - o.y);
}

/// Local equirectangular projection: accurate to < 0.1 % within ~20 km.
class _Origin {
  const _Origin(this.lat, this.lon);

  factory _Origin.of(List<CellSighting> list) {
    var lat = 0.0, lon = 0.0;
    for (final s in list) {
      lat += s.lat!;
      lon += s.lon!;
    }
    return _Origin(lat / list.length, lon / list.length);
  }

  final double lat;
  final double lon;

  double get _k => SiteEstimator._earthR * math.pi / 180;

  _Xy toXy(CellSighting s) => _Xy(
    (s.lon! - lon) * _k * math.cos(lat * math.pi / 180),
    (s.lat! - lat) * _k,
  );

  (double, double) toLatLon(_Xy p) =>
      (lat + p.y / _k, lon + p.x / (_k * math.cos(lat * math.pi / 180)));
}
