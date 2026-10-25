import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/features/latency_test/application/latency_test_controller.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_runner.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';

import '../../fixtures/latency_fixtures.dart';
import '../../fixtures/speed_fixtures.dart';

class ScriptedSpeed extends SpeedTestController {
  ScriptedSpeed(this.after);

  final SpeedTestState after;
  int cancels = 0;

  @override
  SpeedTestState build() => const SpeedTestState();

  @override
  Future<void> start() async => state = after;

  @override
  Future<void> cancel() async => cancels++;
}

class ScriptedLatency extends LatencyTestController {
  ScriptedLatency(this.after);

  final LatencyTestState after;
  int cancels = 0;

  @override
  LatencyTestState build() => const LatencyTestState();

  @override
  Future<void> start() async => state = after;

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  Future<StepOutcome> run(
    ScriptStep step, {
    SpeedTestState speed = const SpeedTestState(),
    LatencyTestState latency = const LatencyTestState(),
  }) {
    final c = ProviderContainer(
      overrides: [
        speedTestControllerProvider.overrideWith(() => ScriptedSpeed(speed)),
        latencyTestControllerProvider.overrideWith(
          () => ScriptedLatency(latency),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c.read(stepExecutorProvider).run(step);
  }

  test('speed step summarises the stored result', () async {
    final o = await run(
      const ScriptStep(StepType.speed),
      speed: const SpeedTestState(result: okResult),
    );
    expect(o.ok, isTrue);
    expect(o.summary, 'DL 48.2 · UL 12.1 Mbps (ok)');
  });

  test('speed step without result fails with the error', () async {
    final o = await run(
      const ScriptStep(StepType.speed),
      speed: const SpeedTestState(error: 'Set a speed-test server URL first.'),
    );
    expect(o.ok, isFalse);
    expect(o.summary, 'Set a speed-test server URL first.');
    final saveError = await run(
      const ScriptStep(StepType.speed),
      speed: const SpeedTestState(result: okResult, error: 'Result not saved'),
    );
    expect(saveError.ok, isFalse);
    expect(saveError.summary, endsWith('Result not saved'));
  });

  test('latency step lists protocol medians', () async {
    final o = await run(
      const ScriptStep(StepType.latency),
      latency: LatencyTestState(results: [latencyResult()]),
    );
    expect(o.ok, isTrue);
    expect(o.summary, 'TCP 27 ms');
    final none = await run(const ScriptStep(StepType.latency));
    expect(none.ok, isFalse);
    expect(none.summary, 'No result');
  });

  test('future step types report not available; cancel reaches both', () async {
    final o = await run(const ScriptStep(StepType.video));
    expect(o.ok, isFalse);
    expect(o.summary, 'Video streaming is not available yet');
    final speed = ScriptedSpeed(const SpeedTestState());
    final latency = ScriptedLatency(const LatencyTestState());
    final c = ProviderContainer(
      overrides: [
        speedTestControllerProvider.overrideWith(() => speed),
        latencyTestControllerProvider.overrideWith(() => latency),
      ],
    );
    addTearDown(c.dispose);
    await c.read(stepExecutorProvider).cancel();
    expect(speed.cancels, 1);
    expect(latency.cancels, 1);
  });
}
