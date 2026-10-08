# Local Storage - Interfaces

## Domain repositories (`lib/domain/repositories/`)
| Interface | Methods |
|---|---|
| `SessionRepository` | `createSession`, `startRecording`, `finishRecording({aborted})`, `getSession`, `watchSessions`, `watchSession`, `deleteSession`, `deleteAllSessions` |
| `SampleRepository` | `recordSample({sessionId, radio, location})` -> measurement_id, `countSamples` |
| `DeviceInfoSource` | `getDeviceInfo()` |
| `DeviceRegistry` | `ensureDevice(info)` -> device_id |

## Platform channel addition
MethodChannel `org.opennetiq/measurement`, method `getDeviceInfo` ->
`{manufacturer, model, android_version, api_level, chipset?, app_version}` (`devices` row; `chipset` = `Build.SOC_MODEL`, API 31+).

## Tables
See `database/mobile/schema_v1.sql` and `docs/standards/DATA-DICTIONARY.md`.
