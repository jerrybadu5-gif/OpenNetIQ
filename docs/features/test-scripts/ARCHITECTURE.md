# Architecture: test scripts (#28)

```
domain/entities/test_script.dart                 StepType, ScriptStep, TestScript (+ JSON, validate)
features/scripts/application/script_store.dart   ScriptStore (app_settings key scripts.v1)
features/scripts/application/script_runner.dart  StepExecutor (ControllerStepExecutor), ScriptRunner
features/scripts/presentation/scripts_screen.dart        list, run card, log
features/scripts/presentation/script_editor_screen.dart  steps, repeat, validation
```

- The runner never measures itself: `ControllerStepExecutor` calls the
  existing speed/latency controllers, so results, methodology version,
  session linking and persistence are identical to manual tests.
- `scriptDelayProvider` and `clockProvider` make waits testable.
- No schema change: scripts are JSON in `app_settings`. Results are not yet
  tagged with a script/run id; #31 (benchmarking) adds that with schema v2.
