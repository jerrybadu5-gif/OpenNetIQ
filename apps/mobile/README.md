# OpenNetIQ Mobile

Flutter app + Kotlin measurement layer. Scaffolded in issue *M0: Flutter skeleton* (`flutter create --org org.opennetiq --platforms android .`).
Structure: see `docs/ARCHITECTURE.md` §2.

## Layout and flavors

Layers (dependency rule: features -> domain <- data -> platform): `lib/core`, `lib/platform`, `lib/data`, `lib/domain`, `lib/features`.

Generate code first (Drift, not committed): `dart run build_runner build --delete-conflicting-outputs`.

Run: `flutter run --flavor dev -t lib/main_dev.dart` (or `prod` with `lib/main_prod.dart`).
Build: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
minSdk 29, targetSdk 35.


## Features
| Feature | Docs | Status |
|---|---|---|
| Signal monitor (2G-5G live cells) | [docs/features/signal-monitor](../../docs/features/signal-monitor/README.md) | M1 |
| Location (GNSS collector) | [docs/features/location](../../docs/features/location/README.md) | M1 |
| Local storage, recording, sessions | [docs/features/local-storage](../../docs/features/local-storage/README.md) | M1 |
