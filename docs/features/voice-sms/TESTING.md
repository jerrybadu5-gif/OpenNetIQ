# Voice and SMS tests — testing

## Automated
| Test | Covers |
|---|---|
| `android/app/src/test/.../voice/VoiceSmsRulesTest.kt` | number validation and masking, call outcome/setup/drop rules, SMS outcomes, TP-Status, token |
| `test/domain/voice_sms_test_test.dart` | line parsing, settings JSON, summaries, permissions map, `voice_sms` consent |
| `test/data/voice_sms_engine_and_store_test.dart` | channel arguments and mapping, store round-trip (no full number), erase, v2 → v3 migration keeps consent rows |
| `test/features/voice_sms/*` | controller (plan, consent refusal, cancel, settings), screen (opt-in, permissions, results, editing) |
| `test/features/scripts/step_executor_test.dart` | call / sms steps |
| `test/data/export/session_export_test.dart` | `_voice_sms.csv`, GeoJSON features |

## On device (#25 protocol)
1. Privacy shows policy 1.1 and asks again; *Allow voice and SMS tests* off by default; Start disabled.
2. Opt in → Android asks for phone, call log and SMS permissions.
3. Call line with auto-answer: outcome *completed*, setup time 3–15 s, connected ≈ window − setup.
4. Call a busy/rejecting number: *rejected*; unanswered: *no answer*; hang up the far end early: *dropped*.
5. Revoke call-log permission: result *partial*, setup time `-`.
6. SMS to `| self` line: *received*, receive time present; SMS to another phone: *delivered* or *no report*.
7. Airplane mode: call *not placed* / SMS *not sent*.
8. Script with Voice call + SMS steps during a drive: rows linked to the drive; export contains `_voice_sms.csv` with `••NN` only.
