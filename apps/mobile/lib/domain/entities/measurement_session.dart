/// Kind of measurement session (`sessions.session_type`).
enum SessionType {
  drive('drive', 'Drive'),
  walk('walk', 'Walk'),
  stationary('static', 'Static'),
  singleTest('single_test', 'Single test');

  const SessionType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SessionType? fromWire(String? value) {
    for (final t in values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }
}

/// Lifecycle (`sessions.status`): created -> recording -> paused ->
/// completed | aborted.
enum SessionStatus {
  created,
  recording,
  paused,
  completed,
  aborted;

  String get wireValue => name;

  bool get isActive => this == recording || this == paused;

  static SessionStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}

/// A recorded measurement session (drive, walk, static or single test).
class MeasurementSession {
  const MeasurementSession({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.type,
    required this.status,
    required this.samplingIntervalMs,
    required this.methodologyVersion,
    required this.sampleCount,
    required this.createdAt,
    required this.updatedAt,
    this.operatorUnderTest,
    this.notes,
    this.startedAt,
    this.endedAt,
    this.distanceM,
  });

  final String id;
  final String deviceId;
  final String name;
  final SessionType type;
  final SessionStatus status;
  final int samplingIntervalMs;
  final String methodologyVersion;
  final int sampleCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? operatorUnderTest;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final double? distanceM;

  /// Elapsed recording time; uses [now] while the session is still active.
  Duration? duration({DateTime? now}) {
    final start = startedAt;
    if (start == null) return null;
    final end = endedAt ?? now;
    return end?.difference(start);
  }
}
