# Voice and SMS tests — platform API

MethodChannel `org.opennetiq/voice_sms`.

| Method | Arguments | Returns |
|---|---|---|
| `permissions` | — | `{call, end_call, call_log, send_sms, receive_sms, has_telephony}` (bool) |
| `request_permissions` | — | same map after the Android dialog (`NO_ACTIVITY`, `IN_PROGRESS` errors) |
| `call` | `number` (String), `window_ms` (int, 10 000–600 000: release after dialling), `setup_timeout_ms` (int, 1 000–window) | result map (call) |
| `sms` | `number`, `loopback` (bool), `timeout_ms` (int, 5 000–600 000) | result map (sms) |
| `cancel` | — | null; the running call is released / SMS wait ends with error `cancelled` |

Result map (`null` = unavailable):

| Key | Kind | Meaning |
|---|---|---|
| `status` | both | `ok` / `partial` / `failed` |
| `outcome` | both | see DATA-DICTIONARY `voice_sms_tests.outcome` |
| `target_masked` | both | `••` + last two digits |
| `error` | both | reason or null |
| `window_s`, `setup_timeout_s`, `call_ms`, `setup_ms`, `connected_s`, `dropped`, `voice_rat` | call | timings (ms), seconds, bool, `GSM`/`UMTS`/`VoLTE`/`VoNR` sequence |
| `loopback`, `send_ms`, `delivery_ms`, `receive_ms`, `result_code` | sms | timings from submission (ms), SmsManager result code |

The full number is passed in only and never returned. Settings JSON
(`app_settings` key `voice_sms.settings.v1`, version 2):
`{call_targets:[{name, number}], sms_targets:[{name, number, loopback?}], setup_timeout_s (20), hold_s (120), interval_s (30), sms_timeout_s (60)}`.
