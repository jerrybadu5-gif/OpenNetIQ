/// Gap detection and completeness for recorded sessions (issue #17,
/// MEASUREMENT-METHODOLOGY.md §6).
library;

/// A user pause; [to] is null while still paused.
class PauseWindow {
  const PauseWindow(this.from, [this.to]);

  final DateTime from;
  final DateTime? to;

  PauseWindow close(DateTime at) => PauseWindow(from, to ?? at);
}

/// Interval between two consecutive samples that is longer than
/// [SampleGaps.gapFactor] x the sampling interval (pauses excluded).
class SampleGap {
  const SampleGap({
    required this.from,
    required this.to,
    required this.missing,
  });

  /// Timestamp of the last sample before the gap.
  final DateTime from;

  /// Timestamp of the first sample after the gap.
  final DateTime to;

  /// Ticks that should have been recorded inside the gap.
  final int missing;

  Duration get length => to.difference(from);
}

class GapReport {
  const GapReport({
    required this.recorded,
    required this.missing,
    required this.gaps,
  });

  static const empty = GapReport(recorded: 0, missing: 0, gaps: []);

  final int recorded;
  final int missing;
  final List<SampleGap> gaps;

  int get expected => recorded + missing;

  /// recorded / expected, null when nothing was expected.
  double? get completeness => expected == 0 ? null : recorded / expected;

  double? get missingPct {
    final c = completeness;
    return c == null ? null : (1 - c) * 100;
  }

  Duration get longestGap => gaps.fold(
    Duration.zero,
    (longest, g) => g.length > longest ? g.length : longest,
  );
}

abstract final class SampleGaps {
  /// A step longer than 1.5 x interval counts as a gap.
  static const double gapFactor = 1.5;

  /// Analyses sample timestamps of one session. Time inside [pauses] is not
  /// expected to contain samples.
  static GapReport analyse(
    List<DateTime> timestamps,
    Duration interval, {
    List<PauseWindow> pauses = const [],
  }) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'must be positive');
    }
    final sorted = [...timestamps]..sort();
    final gaps = <SampleGap>[];
    var missing = 0;
    for (var i = 1; i < sorted.length; i++) {
      final a = sorted[i - 1];
      final b = sorted[i];
      final active = b.difference(a) - _pausedWithin(a, b, pauses);
      final steps = active.inMicroseconds / interval.inMicroseconds;
      if (steps > gapFactor) {
        final m = steps.round() - 1;
        final count = m < 1 ? 1 : m;
        missing += count;
        gaps.add(SampleGap(from: a, to: b, missing: count));
      }
    }
    return GapReport(recorded: sorted.length, missing: missing, gaps: gaps);
  }

  /// Live completeness: recorded vs. ticks expected in [active] time.
  /// Null until one full interval has elapsed. Capped at 1.
  static double? liveCompleteness(
    int recorded,
    Duration active,
    Duration interval,
  ) {
    final expected = active.inMicroseconds ~/ interval.inMicroseconds;
    if (expected <= 0) return null;
    final ratio = recorded / expected;
    return ratio > 1 ? 1.0 : ratio;
  }

  static Duration _pausedWithin(
    DateTime a,
    DateTime b,
    List<PauseWindow> pauses,
  ) {
    var total = Duration.zero;
    for (final p in pauses) {
      final end = p.to ?? b;
      final from = p.from.isAfter(a) ? p.from : a;
      final to = end.isBefore(b) ? end : b;
      if (to.isAfter(from)) total += to.difference(from);
    }
    return total;
  }
}
