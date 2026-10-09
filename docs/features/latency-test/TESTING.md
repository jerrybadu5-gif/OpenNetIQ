# Latency Engine — Testing

## Automated
| Suite | Covers |
|---|---|
| `LatencyMathTest.kt` | Min/max/mean/median, nearest-rank P95, IPDV jitter over consecutive successful pairs, loss, status rule |
| `PingAndDnsTest.kt` | `ping` output parsing (loss, reordering, DUP, `time<1`), command line, host validation (shell characters rejected), DNS wire format |
| `LatencyEngineTest.kt` | Real TCP connects to a local port, closed port = 100 % loss, 200 ms spacing, DNS against a local UDP resolver (one dropped reply), missing resolver / IP target, ICMP via a fake `ping` process, cancel |
| `test/data/latency_test_engine_test.dart` | Event mapping, server URL -> target, channel arguments, error mapping, cancel |
| `test/data/local/latency_store_test.dart` | One row per protocol, JSON raw RTTs, ordering, rollback on failure |
| `test/features/latency_test_controller_test.dart` | Target from server URL, live probes, rows linked to one `single_test` session, cancel, errors |
| `test/features/latency_test_screen_test.dart` | Target, start/cancel, live count, result cards |

```powershell
cd apps\mobile
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze --fatal-infos
flutter test
cd android; .\gradlew.bat testDevDebugUnitTest "-Ptarget=lib/main_dev.dart"; cd ..
```

## Device check
1. Test server running (`infra/test-server`) and set on the Speed test screen.
2. Home -> Latency test -> Start: ICMP, TCP, DNS each count to 20; results in about 15 s.
3. Compare with `ping -c 20 -i 0.2 <server>` from a PC on the same network: medians within a few ms on Wi-Fi.
4. Cancel during TCP: stops at once, nothing stored. Sessions shows a `Single test` per completed run.
