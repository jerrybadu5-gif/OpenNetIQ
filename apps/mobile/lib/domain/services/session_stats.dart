import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

/// Distribution of a level metric (dBm).
class LevelStats {
  const LevelStats({
    required this.count,
    required this.min,
    required this.median,
    required this.mean,
    required this.max,
  });

  final int count;
  final double min;
  final double median;
  final double mean;
  final double max;

  static LevelStats? of(Iterable<double> values) {
    final sorted = [...values]..sort();
    if (sorted.isEmpty) return null;
    final n = sorted.length;
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    final sum = sorted.fold<double>(0, (a, b) => a + b);
    return LevelStats(
      count: n,
      min: sorted.first,
      median: median,
      mean: sum / n,
      max: sorted.last,
    );
  }
}

/// Summary statistics of one session (issue #18). Levels are kept per RAT
/// because RSRP, RSCP and RSSI are different metrics.
class SessionStats {
  const SessionStats({
    required this.samples,
    required this.positioned,
    required this.levelByRat,
    required this.qualityCounts,
    required this.noServiceCell,
    required this.networkCounts,
  });

  final int samples;

  /// Samples with a usable, non-mock position.
  final int positioned;
  final Map<Rat, LevelStats> levelByRat;

  /// Samples per signal class (only samples with a serving-cell level).
  final Map<SignalQuality, int> qualityCounts;

  /// Samples without a serving-cell level.
  final int noServiceCell;
  final Map<NetworkType, int> networkCounts;

  /// Share of [count] in all samples, 0..1 (0 when empty).
  double share(int count) => samples == 0 ? 0 : count / samples;

  factory SessionStats.of(List<SamplePoint> points) {
    final levels = <Rat, List<double>>{};
    final quality = <SignalQuality, int>{};
    final network = <NetworkType, int>{};
    var positioned = 0;
    var noCell = 0;
    for (final p in points) {
      if (p.hasPosition) positioned++;
      final rat = p.rat;
      final level = p.levelDbm;
      final q = p.quality;
      if (rat != null && level != null && q != null) {
        (levels[rat] ??= []).add(level);
        quality[q] = (quality[q] ?? 0) + 1;
      } else {
        noCell++;
      }
      final nt = p.networkType;
      if (nt != null) network[nt] = (network[nt] ?? 0) + 1;
    }
    return SessionStats(
      samples: points.length,
      positioned: positioned,
      levelByRat: {
        for (final e in levels.entries) e.key: LevelStats.of(e.value)!,
      },
      qualityCounts: quality,
      noServiceCell: noCell,
      networkCounts: network,
    );
  }
}
