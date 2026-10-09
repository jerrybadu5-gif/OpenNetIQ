import 'package:opennetiq_mobile/domain/entities/latency_test.dart';

/// Native latency engine (Kotlin). Cancelling the subscription cancels the
/// test; the stream ends after the last [LatencyCompleted].
abstract interface class LatencyEngine {
  Stream<LatencyEvent> run(LatencyConfig config);
}

abstract interface class LatencyStore {
  /// All rows of one run (one per protocol) in one transaction.
  Future<void> saveLatencyTests(List<LatencyRecord> records);

  /// Newest first.
  Stream<List<LatencyRecord>> watchLatencyTests({int limit = 50});
}
