/// Speed-test results (method `http-mc-1.0`, MEASUREMENT-METHODOLOGY.md §5).
library;

/// Statistics of one direction in Mbit/s (SI), bytes transferred.
class ThroughputResult {
  const ThroughputResult({
    required this.meanMbps,
    required this.medianMbps,
    required this.p10Mbps,
    required this.p90Mbps,
    required this.peakMbps,
    required this.bytes,
  });

  final double meanMbps;
  final double medianMbps;
  final double p10Mbps;
  final double p90Mbps;
  final double peakMbps;
  final int bytes;
}

/// `speed_tests.status`.
enum SpeedTestStatus {
  ok,
  partial,
  failed;

  String get wireValue => name;

  static SpeedTestStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}

enum SpeedTestPhase {
  dns('dns', 'Resolving server'),
  download('download', 'Download'),
  upload('upload', 'Upload');

  const SpeedTestPhase(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SpeedTestPhase? fromWire(String? value) {
    for (final p in values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}

class SpeedTestResult {
  const SpeedTestResult({
    required this.status,
    required this.method,
    required this.serverHost,
    required this.streams,
    this.dnsMs,
    this.tcpConnectMs,
    this.download,
    this.upload,
    this.error,
  });

  final SpeedTestStatus status;
  final String method;
  final String serverHost;
  final int streams;
  final double? dnsMs;
  final double? tcpConnectMs;
  final ThroughputResult? download;
  final ThroughputResult? upload;
  final String? error;
}

/// What the native engine reports while a test runs.
sealed class SpeedTestEvent {
  const SpeedTestEvent();
}

final class SpeedTestPhaseChanged extends SpeedTestEvent {
  const SpeedTestPhaseChanged(this.phase);

  final SpeedTestPhase phase;
}

/// Rate over the last second, every sampling interval.
final class SpeedTestProgress extends SpeedTestEvent {
  const SpeedTestProgress(this.phase, this.elapsed, this.mbps);

  final SpeedTestPhase phase;
  final Duration elapsed;
  final double mbps;
}

final class SpeedTestCompleted extends SpeedTestEvent {
  const SpeedTestCompleted(this.result);

  final SpeedTestResult result;
}

/// Parameters sent to the engine; defaults are method `http-mc-1.0`.
class SpeedTestConfig {
  const SpeedTestConfig({
    required this.serverUrl,
    this.streams = 4,
    this.directionDuration = const Duration(seconds: 12),
  });

  /// Base URL of LibreSpeed-compatible endpoints (`garbage.php`, `empty.php`).
  final String serverUrl;
  final int streams;

  /// Per direction, including the 2 s ramp-up.
  final Duration directionDuration;
}

/// A stored `speed_tests` row.
class SpeedTestRecord {
  const SpeedTestRecord({
    required this.id,
    required this.timestamp,
    required this.methodologyVersion,
    required this.serverId,
    required this.result,
    this.sessionId,
    this.measurementId,
    this.ratChanged = false,
  });

  final String id;

  /// Test start (UTC).
  final DateTime timestamp;
  final String methodologyVersion;
  final String serverId;
  final SpeedTestResult result;

  /// Session holding the start snapshot (a `single_test` session for
  /// stand-alone tests).
  final String? sessionId;

  /// Radio/GPS sample at the start of the test.
  final String? measurementId;

  /// The network type changed during the test (flagged, not dropped).
  final bool ratChanged;
}
