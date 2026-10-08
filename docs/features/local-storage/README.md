# Local Storage (Drift / SQLite)

On-device database for measurement sessions. Closes #16.

## What it does
- Schema v1 exactly as `database/mobile/schema_v1.sql` (8 tables), enforced by a test that parses the reference DDL.
- SQLite file `opennetiq.sqlite` in the app's private storage, WAL journal, foreign keys on. App backup is disabled (`allowBackup="false"`) so measurements never leave the phone via cloud backup.
- Every radio tick while recording = one `samples` row (geotagged with the GPS fix of the same tick, if any) + one `cell_observations` row per visible cell, written in one transaction together with the session's sample count and distance.
- Device registered once with a random UUIDv7 (`app_settings.device_id`), never IMEI.
- **Recording (foreground)**: Signal monitor -> record button in the app bar -> `REC n` counter -> tap to stop. Recording continues in the background via the drive-test service (#17, `docs/features/drive-test/`).
- **Sessions screen** (Home -> Sessions): list with samples, distance, duration; delete one or all (privacy control).

## Data quality on samples
| Flag | When |
|---|---|
| `NO_GPS_FIX` | No fix, `gps_quality = NONE`, or location more than 2 s apart from the radio tick |
| `MOCK_LOCATION` | Mock-location provider |
| `STALE`, `CACHED`, `NO_PHONE_STATE` | Copied from the radio snapshot |

Distance counts only consecutive `GOOD`, non-mock fixes; jumps over 500 m between samples are treated as GNSS glitches.

## Developer setup
Generated Drift code is not committed:
```powershell
cd apps\mobile
dart run build_runner build --delete-conflicting-outputs
```
Run it after every pull that changes `lib/data/local/tables.dart` or `app_database.dart`.
