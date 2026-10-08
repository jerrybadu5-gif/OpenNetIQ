# Drive Test — Platform API

Control channel `org.opennetiq/measurement` (MethodChannel, ADR-013). Additions for #17.

## Dart -> Kotlin
| Method | Arguments | Result | Errors |
|---|---|---|---|
| `startRecordingService` | `{title: String, text: String}` | `null` | `PERMISSION_DENIED` (no precise location), `SERVICE_UNAVAILABLE` (app not visible) |
| `updateRecordingService` | `{title, text}` | `null` (no-op if not running) | – |
| `stopRecordingService` | – | `null` | – |
| `getBatteryOptimization` | – | `{ignoring: bool}` | – |
| `openBatterySettings` | – | `bool` (settings opened) | – |

Title is trimmed and capped at 80 chars (default `Drive test recording`); text at 200 chars.

## Kotlin -> Dart
| Method | Arguments | Expected reply |
|---|---|---|
| `onStopRequested` | – | `true` if a session took the request; anything else (or no handler) and the service stops itself |
| `onServiceError` | `{code: String, message: String}` | ignored. `code`: `FOREGROUND_DENIED` |

## Radio / location streams
Unchanged. The `interval_ms` argument now carries the session interval (1000, 2000 or 5000) while recording.

## Local database
- `sessions.status` uses `paused` while paused; resume sets `recording` again (`started_at` kept).
- Crash recovery: `UPDATE sessions SET status='aborted', ended_at = COALESCE(MAX(samples.timestamp), started_at, created_at) WHERE status IN ('created','recording','paused')`, once per process start.
