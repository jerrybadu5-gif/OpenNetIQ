# API: test scripts (#28)

Script JSON (format 1), also the future exchange format (#31):

```json
{"format": 1, "id": "019a…", "name": "Drive loop",
 "steps": [{"type": "speed"}, {"type": "wait", "seconds": 30}, {"type": "latency"}],
 "cycles": 0, "cycle_interval_s": 120}
```

| Field | Rule |
|---|---|
| `steps[].type` | `speed`, `latency`, `wait` (now); `web`, `video`, `apps`, `file`, `call`, `sms` reserved |
| `steps[].seconds` | wait duration, > 0 |
| `cycles` | ≥ 0; 0 = until stopped |
| `cycle_interval_s` | optional, > 0; next cycle starts this long after the previous one started |

`ScriptRunner.start(script)` returns when the script ends; `stop()` cancels
the running step. `StepExecutor.run(step)` → `StepOutcome(ok, summary)`.
