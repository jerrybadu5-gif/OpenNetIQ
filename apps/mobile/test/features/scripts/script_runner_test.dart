import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_runner.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_store.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../../fixtures/script_fixtures.dart';

void main() {
  late FakeStepExecutor executor;
  late List<Duration> delays;
  late DateTime now;

  ProviderContainer container({MemorySettings? settings}) {
    final c = ProviderContainer(
      overrides: [
        stepExecutorProvider.overrideWithValue(executor),
        scriptDelayProvider.overrideWithValue((d) async {
          delays.add(d);
          now = now.add(d);
        }),
        clockProvider.overrideWithValue(() => now),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? MemorySettings(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    executor = FakeStepExecutor();
    delays = [];
    now = DateTime.utc(2026, 10, 25, 1);
  });

  test('runs every step of every cycle and logs outcomes', () async {
    final c = container();
    await c.read(scriptRunnerProvider.notifier).start(speedLatency);
    final s = c.read(scriptRunnerProvider);
    expect(executor.ran, [
      StepType.speed,
      StepType.latency,
      StepType.speed,
      StepType.latency,
    ]);
    expect(delays, [const Duration(seconds: 5), const Duration(seconds: 5)]);
    expect(s.running, isFalse);
    expect(s.message, 'Finished');
    expect(s.log, hasLength(6));
    expect(s.log.last.cycle, 2);
    expect(s.log.first.summary, 'speed done');
  });

  test('interval: waits for the rest of the cycle', () async {
    executor.onRun = () => now = now.add(const Duration(seconds: 20));
    const script = TestScript(
      id: 'i',
      name: 'I',
      steps: [ScriptStep(StepType.speed)],
      cycles: 2,
      cycleIntervalSeconds: 60,
    );
    final c = container();
    await c.read(scriptRunnerProvider.notifier).start(script);
    expect(delays, [const Duration(seconds: 40)]);
    expect(executor.ran, hasLength(2));
  });

  test('stop ends an unlimited script and cancels the test', () async {
    final c = container();
    final runner = c.read(scriptRunnerProvider.notifier);
    executor.onRun = () {
      if (executor.ran.length == 3) runner.stop();
    };
    const script = TestScript(
      id: 'u',
      name: 'U',
      steps: [ScriptStep(StepType.speed)],
      cycles: 0,
    );
    await runner.start(script);
    final s = c.read(scriptRunnerProvider);
    expect(s.message, 'Stopped');
    expect(executor.ran, hasLength(3));
    expect(executor.cancels, 1);
    expect(s.log, hasLength(2)); // the cancelled step is not logged
    await runner.stop(); // no-op when idle
    expect(executor.cancels, 1);
  });

  test('failures and errors are logged, the script continues', () async {
    executor
      ..failType = StepType.speed
      ..throwOn = StateError('boom');
    final c = container();
    await c
        .read(scriptRunnerProvider.notifier)
        .start(speedLatency.copyWith(cycles: 1));
    final log = c.read(scriptRunnerProvider).log;
    expect(log.first.ok, isFalse);
    expect(log.last.ok, isFalse);
    expect(log.last.summary, contains('boom'));
  });

  test('invalid script is not started', () async {
    final c = container();
    await c
        .read(scriptRunnerProvider.notifier)
        .start(const TestScript(id: 'x', name: '', steps: []));
    final s = c.read(scriptRunnerProvider);
    expect(s.running, isFalse);
    expect(s.message, 'Give the script a name');
    expect(executor.ran, isEmpty);
  });

  test('state labels', () {
    const s = ScriptRunState(script: speedLatency, stepIndex: 1, running: true);
    expect(s.stepLabel, 'Wait 5 s');
    expect(const ScriptRunState().stepLabel, '');
    expect(
      ScriptRunState(
        script: speedLatency,
        waitingUntil: DateTime(2026),
      ).stepLabel,
      'Waiting for next cycle',
    );
  });

  group('store', () {
    test('presets until saved; save, update, delete persist', () async {
      final settings = MemorySettings();
      final c = container(settings: settings);
      expect(await c.read(scriptStoreProvider.future), presetScripts);
      final store = c.read(scriptStoreProvider.notifier);
      await store.save(speedLatency);
      expect(settings.values[scriptsKey], contains('Two steps'));
      await store.save(speedLatency.copyWith(name: 'Renamed'));
      final list = await c.read(scriptStoreProvider.future);
      expect(list.where((s) => s.id == 's1').single.name, 'Renamed');
      expect(list, hasLength(presetScripts.length + 1));
      await store.delete('s1');
      expect(
        await c.read(scriptStoreProvider.future),
        hasLength(presetScripts.length),
      );

      final reread = container(settings: settings);
      expect(
        await reread.read(scriptStoreProvider.future),
        hasLength(presetScripts.length),
      );
    });

    test('unreadable value falls back to presets', () async {
      final settings = MemorySettings()..values[scriptsKey] = '{oops';
      final c = container(settings: settings);
      expect(await c.read(scriptStoreProvider.future), presetScripts);
    });
  });
}
