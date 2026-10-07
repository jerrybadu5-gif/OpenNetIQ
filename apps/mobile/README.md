# OpenNetIQ Mobile

Flutter app + Kotlin measurement layer. Scaffolded in issue *M0: Flutter skeleton* (`flutter create --org org.opennetiq --platforms android .`).
Structure: see `docs/ARCHITECTURE.md` §2.

## Layout and flavors

Layers (dependency rule: features -> domain <- data -> platform): `lib/core`, `lib/platform`, `lib/data`, `lib/domain`, `lib/features`.

Run: `flutter run --flavor dev -t lib/main_dev.dart` (or `prod` with `lib/main_prod.dart`).
Build: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
minSdk 29, targetSdk 35.

