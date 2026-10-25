import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/features/latency_test/application/latency_test_controller.dart';
import 'package:opennetiq_mobile/features/qoe/application/qoe_controller.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';

class StepOutcome {
  const StepOutcome({required this.ok, required this.summary});

  final bool ok;
  final String summary;
}

/// Runs one test step to completion (results are stored by the test's own
/// controller, linked to the open drive session if any).
abstract interface class StepExecutor {
  Future<StepOutcome> run(ScriptStep step);

  Future<void> cancel();
}

class ControllerStepExecutor implements StepExecutor {
  const ControllerStepExecutor(this._ref);

  final Ref _ref;

  static String mbps(double? v) => v == null ? '-' : v.toStringAsFixed(1);

  @override
  Future<StepOutcome> run(ScriptStep step) async {
    switch (step.type) {
      case StepType.speed:
        await _ref.read(speedTestControllerProvider.notifier).start();
        final s = _ref.read(speedTestControllerProvider);
        final r = s.result;
        if (r == null) {
          return StepOutcome(ok: false, summary: s.error ?? 'No result');
        }
        return StepOutcome(
          ok: s.error == null && r.status.wireValue != 'failed',
          summary:
              'DL ${mbps(r.download?.meanMbps)} · UL ${mbps(r.upload?.meanMbps)} '
              'Mbps (${r.status.wireValue})${s.error == null ? '' : ' · ${s.error}'}',
        );
      case StepType.latency:
        await _ref.read(latencyTestControllerProvider.notifier).start();
        final s = _ref.read(latencyTestControllerProvider);
        if (s.results.isEmpty) {
          return StepOutcome(ok: false, summary: s.error ?? 'No result');
        }
        return StepOutcome(
          ok: s.error == null,
          summary: [
            for (final r in s.results)
              '${r.protocol.wireValue.toUpperCase()} '
                  '${r.medianMs == null ? '-' : r.medianMs!.toStringAsFixed(0)} ms',
            if (s.error != null) s.error!,
          ].join(' · '),
        );
      case StepType.web || StepType.video || StepType.apps || StepType.file:
        final kind = switch (step.type) {
          StepType.web => QoeKind.web,
          StepType.video => QoeKind.video,
          StepType.apps => QoeKind.app,
          _ => QoeKind.file,
        };
        await _ref.read(qoeTestControllerProvider.notifier).run({kind});
        final s = _ref.read(qoeTestControllerProvider);
        if (s.results.isEmpty) {
          return StepOutcome(ok: false, summary: s.error ?? 'No result');
        }
        final failed = s.results
            .where((r) => r.status == TestStatus.failed)
            .length;
        return StepOutcome(
          ok: failed == 0 && s.error == null,
          summary: [
            for (final r in s.results) '${r.label}: ${r.summary}',
            if (s.error != null) s.error!,
          ].join(' · '),
        );
      case final other:
        return StepOutcome(
          ok: false,
          summary: '${other.label} is not available yet',
        );
    }
  }

  @override
  Future<void> cancel() async {
    await _ref.read(speedTestControllerProvider.notifier).cancel();
    await _ref.read(latencyTestControllerProvider.notifier).cancel();
    await _ref.read(qoeTestControllerProvider.notifier).cancel();
  }
}

final stepExecutorProvider = Provider<StepExecutor>(ControllerStepExecutor.new);

/// Waits; overridable so tests do not sleep.
final scriptDelayProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

class ScriptLogEntry {
  const ScriptLogEntry({
    required this.time,
    required this.cycle,
    required this.step,
    required this.ok,
    required this.summary,
  });

  final DateTime time;
  final int cycle;
  final String step;
  final bool ok;
  final String summary;
}

class ScriptRunState {
  const ScriptRunState({
    this.script,
    this.running = false,
    this.cycle = 0,
    this.stepIndex,
    this.waitingUntil,
    this.log = const [],
    this.message,
  });

  final TestScript? script;
  final bool running;

  /// Current pass, 1-based.
  final int cycle;

  /// Step being run; null between steps or while waiting for the next pass.
  final int? stepIndex;

  /// Next pass starts at (interval scripts).
  final DateTime? waitingUntil;

  /// Newest last; capped at [maxLog].
  final List<ScriptLogEntry> log;
  final String? message;

  static const int maxLog = 200;

  String get stepLabel {
    final i = stepIndex;
    final s = script;
    if (s == null) return '';
    if (i == null) return waitingUntil == null ? '' : 'Waiting for next cycle';
    return s.steps[i].label;
  }

  ScriptRunState copyWith({
    int? cycle,
    int? Function()? stepIndex,
    DateTime? Function()? waitingUntil,
    List<ScriptLogEntry>? log,
  }) => ScriptRunState(
    script: script,
    running: running,
    cycle: cycle ?? this.cycle,
    stepIndex: stepIndex == null ? this.stepIndex : stepIndex(),
    waitingUntil: waitingUntil == null ? this.waitingUntil : waitingUntil(),
    log: log ?? this.log,
    message: message,
  );
}

/// Runs a [TestScript] unattended (issue #28). Survives screen changes; a
/// drive recording keeps the process alive with the screen off.
class ScriptRunner extends Notifier<ScriptRunState> {
  Completer<void>? _stopSignal;

  @override
  ScriptRunState build() => const ScriptRunState();

  bool get _stopped => _stopSignal?.isCompleted ?? true;

  Future<void> start(TestScript script) async {
    if (state.running) return;
    final problems = script.validate();
    if (problems.isNotEmpty) {
      state = ScriptRunState(script: script, message: problems.first);
      return;
    }
    final stop = Completer<void>();
    _stopSignal = stop;
    final now = ref.read(clockProvider);
    final executor = ref.read(stepExecutorProvider);
    state = ScriptRunState(script: script, running: true);
    for (var cycle = 1; script.unlimited || cycle <= script.cycles; cycle++) {
      final cycleStart = now();
      state = state.copyWith(cycle: cycle, waitingUntil: () => null);
      for (var i = 0; i < script.steps.length && !_stopped; i++) {
        final step = script.steps[i];
        state = state.copyWith(stepIndex: () => i);
        StepOutcome outcome;
        if (step.type == StepType.wait) {
          await _sleep(Duration(seconds: step.seconds ?? 0));
          outcome = const StepOutcome(ok: true, summary: 'Waited');
        } else {
          try {
            outcome = await executor.run(step);
          } on Object catch (e) {
            outcome = StepOutcome(ok: false, summary: '$e');
          }
        }
        if (_stopped) break;
        _log(cycle, step.label, outcome);
      }
      if (_stopped) break;
      final more = script.unlimited || cycle < script.cycles;
      final interval = script.cycleIntervalSeconds;
      if (more && interval != null) {
        final next = cycleStart.add(Duration(seconds: interval));
        final remaining = next.difference(now());
        if (remaining > Duration.zero) {
          state = state.copyWith(
            stepIndex: () => null,
            waitingUntil: () => next,
          );
          await _sleep(remaining);
          if (_stopped) break;
        }
      }
    }
    final cancelled = _stopped;
    if (!stop.isCompleted) stop.complete();
    state = ScriptRunState(
      script: script,
      cycle: state.cycle,
      log: state.log,
      message: cancelled ? 'Stopped' : 'Finished',
    );
  }

  /// Stops after cancelling the running test; finished results stay saved.
  Future<void> stop() async {
    final stop = _stopSignal;
    if (!state.running || stop == null || stop.isCompleted) return;
    stop.complete();
    await ref.read(stepExecutorProvider).cancel();
  }

  Future<void> _sleep(Duration d) =>
      Future.any([ref.read(scriptDelayProvider)(d), _stopSignal!.future]);

  void _log(int cycle, String step, StepOutcome o) {
    final log = [
      ...state.log,
      ScriptLogEntry(
        time: ref.read(clockProvider)(),
        cycle: cycle,
        step: step,
        ok: o.ok,
        summary: o.summary,
      ),
    ];
    state = state.copyWith(
      log: log.length > ScriptRunState.maxLog
          ? log.sublist(log.length - ScriptRunState.maxLog)
          : log,
    );
  }
}

final scriptRunnerProvider = NotifierProvider<ScriptRunner, ScriptRunState>(
  ScriptRunner.new,
);
