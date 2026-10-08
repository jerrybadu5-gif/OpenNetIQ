import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/services/sample_gaps.dart';

void main() {
  const second = Duration(seconds: 1);
  final t0 = DateTime.utc(2026, 10, 8, 1);
  List<DateTime> at(List<double> seconds) => [
    for (final s in seconds) t0.add(Duration(milliseconds: (s * 1000).round())),
  ];

  group('analyse', () {
    test('regular ticks have no gaps', () {
      final r = SampleGaps.analyse(at([0, 1, 2, 3, 4.2, 5]), second);
      expect(r.recorded, 6);
      expect(r.missing, 0);
      expect(r.gaps, isEmpty);
      expect(r.completeness, 1);
      expect(r.missingPct, 0);
      expect(r.longestGap, Duration.zero);
    });

    test('counts missing ticks inside gaps', () {
      final r = SampleGaps.analyse(at([0, 1, 5, 6, 7.6]), second);
      expect(r.gaps, hasLength(2));
      expect(r.gaps.first.missing, 3);
      expect(r.gaps.first.length, const Duration(seconds: 4));
      expect(r.gaps.last.missing, 1);
      expect(r.missing, 4);
      expect(r.expected, 9);
      expect(r.completeness, closeTo(5 / 9, 1e-9));
      expect(r.longestGap, const Duration(seconds: 4));
    });

    test('scales with the sampling interval and sorts input', () {
      final r = SampleGaps.analyse(
        at([20, 0, 5, 10]),
        const Duration(seconds: 5),
      );
      expect(r.missing, 1);
      expect(r.gaps.single.from, t0.add(const Duration(seconds: 10)));
    });

    test('pauses are not gaps', () {
      final pause = PauseWindow(
        t0.add(const Duration(milliseconds: 1500)),
        t0.add(const Duration(milliseconds: 31500)),
      );
      final r = SampleGaps.analyse(at([0, 1, 32, 33]), second, pauses: [pause]);
      expect(r.gaps, isEmpty);
      expect(r.completeness, 1);
    });

    test('an open pause runs to the next sample', () {
      final r = SampleGaps.analyse(
        at([0, 10]),
        second,
        pauses: [PauseWindow(t0.add(const Duration(milliseconds: 500)))],
      );
      expect(r.gaps, isEmpty);
    });

    test('empty and single sample sessions', () {
      expect(SampleGaps.analyse([], second).completeness, isNull);
      expect(GapReport.empty.missingPct, isNull);
      expect(SampleGaps.analyse(at([0]), second).completeness, 1);
    });

    test('rejects a non-positive interval', () {
      expect(
        () => SampleGaps.analyse(at([0]), Duration.zero),
        throwsArgumentError,
      );
    });
  });

  test('PauseWindow.close keeps an existing end', () {
    final closed = PauseWindow(t0).close(t0.add(second));
    expect(closed.to, t0.add(second));
    expect(closed.close(t0.add(second * 5)).to, t0.add(second));
  });

  group('liveCompleteness', () {
    test('is null before one interval elapsed', () {
      expect(SampleGaps.liveCompleteness(1, Duration.zero, second), isNull);
    });

    test('ratio of recorded to expected ticks, capped at 1', () {
      expect(
        SampleGaps.liveCompleteness(90, const Duration(seconds: 100), second),
        closeTo(0.9, 1e-9),
      );
      expect(
        SampleGaps.liveCompleteness(11, const Duration(seconds: 10), second),
        1,
      );
    });
  });
}
