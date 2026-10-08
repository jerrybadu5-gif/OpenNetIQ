# Drive Test (foreground service & session engine)

Records measurement sessions with the screen off or the app swiped away. Closes #17.

## What it does
- **Home -> Drive test**: name, type (Drive / Walk / Static), sampling interval **1 / 2 / 5 s**, operator under test, then **Start recording**.
- Recording runs in a foreground service (type `location`) with an ongoing notification: `120 samples - LTE - RSRP -95 dBm - GPS Good`. Tap it to open the app; **Stop** ends the session.
- Live status: elapsed active time, samples, completeness, network and GPS, **Pause / Resume / Stop** (Stop asks for confirmation).
- Lifecycle `created -> recording <-> paused -> completed | aborted`. Each sample is committed in its own transaction (WAL), so a crash loses at most the tick in flight.
- **Crash recovery**: if Android kills the process, the session is closed as `aborted` at its last sample when the app next starts.
- **Gap detection**: after Stop the screen shows samples, expected, missing (%), number of gaps and the longest gap. Pauses are not counted as gaps.
- A banner on Home shows an open session from anywhere in the app. The signal monitor no longer blocks leaving the screen while recording.
- Battery: warns when battery optimisation is on and opens the system list to exempt OpenNetIQ.

## Permissions
| Permission | Why |
|---|---|
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Foreground service of type `location` (Android 14+) |
| `WAKE_LOCK` | Keep sampling with the screen off (released at Stop, 12 h cap) |
| `POST_NOTIFICATIONS` | Show the recording notification (asked at first Start on Android 13+; recording works without it) |

No `ACCESS_BACKGROUND_LOCATION`: the service is always started while the app is visible.

## Acceptance (field)
2 h screen-off run, missing samples <= 1 %, battery <= 15 %/h, survives swipe-away. See `TESTING.md`.
