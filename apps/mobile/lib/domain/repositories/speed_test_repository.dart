import 'package:opennetiq_mobile/domain/entities/speed_test.dart';

/// Native throughput engine (Kotlin, ADR-005). Cancelling the subscription
/// cancels the test; the stream ends after [SpeedTestCompleted].
abstract interface class SpeedTestEngine {
  Stream<SpeedTestEvent> run(SpeedTestConfig config);
}

abstract interface class SpeedTestStore {
  Future<void> saveSpeedTest(SpeedTestRecord record);

  /// Newest first.
  Stream<List<SpeedTestRecord>> watchSpeedTests({int limit = 50});
}

/// Key/value app settings (`app_settings`).
abstract interface class SettingsRepository {
  Future<String?> getSetting(String key);

  Future<void> setSetting(String key, String value);
}
