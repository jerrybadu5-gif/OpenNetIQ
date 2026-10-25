# Testing: test scripts (#28)

## Automated
- `test/domain/test_script_test.dart`: JSON round trip, validation, summary.
- `test/features/scripts/script_runner_test.dart`: cycles, waits, interval
  remainder, stop, failures, invalid scripts, store persistence/fallback.
- `test/features/scripts/step_executor_test.dart`: speed/latency summaries,
  errors, unavailable steps, cancel.
- `test/features/scripts/scripts_screen_test.dart`: presets, run log,
  recording banner, progress + stop, editor create/edit/delete.

## On device
1. Set the test server (Speed test screen).
2. Test scripts → run *Quick check*: latency then speed; log shows both.
3. Start a drive test recording, then run *Drive loop*; turn the screen off
   for 5 minutes; check the log shows a cycle every 2 minutes and the
   session export `_tests.csv` contains the results with positions.
4. Stop: the running test is cancelled and the script ends.
