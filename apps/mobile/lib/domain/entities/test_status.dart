/// Outcome of an active test (`speed_tests.status`, `latency_tests.status`).
enum TestStatus {
  ok,
  partial,
  failed;

  String get wireValue => name;

  static TestStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}
