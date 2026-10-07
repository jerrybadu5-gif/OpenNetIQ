# OpenNetIQ Mobile

Flutter app + Kotlin measurement layer. Scaffolded in issue *M0: Flutter skeleton* (`flutter create --org org.opennetiq --platforms android .`).
Structure: see `docs/ARCHITECTURE.md` §2.

## Layout and flavors

Layers (dependency rule: features -> domain <- data -> platform): `lib/core`, `lib/platform`, `lib/data`, `lib/domain`, `lib/features`.

Run: `flutter run --flavor dev -t lib/main_dev.dart` (or `prod` with `lib/main_prod.dart`).
Build: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
minSdk 29, targetSdk 35.

## Latency engine

The Android latency engine is exposed to Flutter on the `opennetiq/latency`
method channel. Call `measure` with `protocol` (`icmp`, `tcp`, or `dns`) and
`target`; `port` is optional and defaults to 443. Each run sends 20 probes at
200 ms intervals. ICMP uses Android's system `ping` executable and requires no
root access. TCP and DNS use Android's standard networking APIs.

The response contains the RTT summary, RFC 3393 jitter, loss percentage,
`raw_rtts_ms` in probe order (`null` for failed probes), and
`methodology_version`. See `docs/standards/MEASUREMENT-METHODOLOGY.md` §6 for
the measurement definition.

Run Kotlin unit tests with `cd android && ./gradlew testDevDebugUnitTest`.
