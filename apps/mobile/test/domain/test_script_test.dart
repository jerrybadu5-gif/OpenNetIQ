import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';

void main() {
  test('JSON round trip', () {
    const s = TestScript(
      id: 'x',
      name: 'Drive',
      steps: [
        ScriptStep(StepType.speed),
        ScriptStep(StepType.wait, seconds: 30),
      ],
      cycles: 0,
      cycleIntervalSeconds: 300,
    );
    final back = TestScript.fromJson(
      (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.name, 'Drive');
    expect(back.steps.map((e) => e.label), ['Speed test', 'Wait 30 s']);
    expect(back.unlimited, isTrue);
    expect(back.cycleIntervalSeconds, 300);
    expect(back.summary, 'Speed test → Wait 30 s · until stopped, every 5 min');
    expect(s.toJson()['format'], TestScript.formatVersion);
  });

  test('unknown step type is rejected', () {
    expect(
      () => ScriptStep.fromJson({'type': 'teleport'}),
      throwsFormatException,
    );
    expect(StepType.fromWire('sms'), StepType.sms);
  });

  test('validation', () {
    const empty = TestScript(id: 'a', name: ' ', steps: []);
    expect(
      empty.validate(),
      containsAll(['Give the script a name', 'Add at least one step']),
    );
    const onlyWait = TestScript(
      id: 'b',
      name: 'W',
      steps: [ScriptStep(StepType.wait)],
      cycles: -1,
      cycleIntervalSeconds: 0,
    );
    expect(
      onlyWait.validate(),
      containsAll([
        'Add a test step',
        'Wait steps need a duration',
        'Cycles cannot be negative',
        'Interval must be positive',
      ]),
    );
    const future = TestScript(
      id: 'c',
      name: 'C',
      steps: [ScriptStep(StepType.sms)],
    );
    expect(future.validate(), ['SMS is not available yet']);
    expect(presetScripts.every((p) => p.validate().isEmpty), isTrue);
    expect(presetScripts.first.summary, 'Latency test → Speed test · once');
    const thrice = TestScript(
      id: 'd',
      name: 'D',
      steps: [ScriptStep(StepType.speed)],
      cycles: 3,
      cycleIntervalSeconds: 45,
    );
    expect(thrice.summary, 'Speed test · 3 times, every 45 s');
    expect(
      thrice.copyWith(cycleIntervalSeconds: () => null).cycleIntervalSeconds,
      isNull,
    );
    expect(thrice.copyWith(name: 'E').cycleIntervalSeconds, 45);
  });
}
