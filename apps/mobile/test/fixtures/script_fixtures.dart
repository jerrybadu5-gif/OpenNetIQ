import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/domain/repositories/speed_test_repository.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_runner.dart';

class MemorySettings implements SettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      values[key] = value;
}

/// Records steps; optional per-type outcome or error.
class FakeStepExecutor implements StepExecutor {
  final ran = <StepType>[];
  int cancels = 0;
  Object? throwOn;
  StepType? failType;

  /// Called before returning; lets a test stop the runner mid-step.
  void Function()? onRun;

  @override
  Future<StepOutcome> run(ScriptStep step) async {
    ran.add(step.type);
    onRun?.call();
    if (throwOn != null && step.type == StepType.latency) throw throwOn!;
    return StepOutcome(
      ok: step.type != failType,
      summary: '${step.type.wireValue} done',
    );
  }

  @override
  Future<void> cancel() async => cancels++;
}

const speedLatency = TestScript(
  id: 's1',
  name: 'Two steps',
  steps: [
    ScriptStep(StepType.speed),
    ScriptStep(StepType.wait, seconds: 5),
    ScriptStep(StepType.latency),
  ],
  cycles: 2,
);
