/// Latency results (method `lat-1.0`, MEASUREMENT-METHODOLOGY.md §6).
library;

import 'package:opennetiq_mobile/domain/entities/test_status.dart';

export 'package:opennetiq_mobile/domain/entities/test_status.dart';

/// `latency_tests.protocol` (http is reserved for a later method).
enum LatencyProtocol {
  icmp('icmp', 'ICMP ping'),
  tcp('tcp', 'TCP connect'),
  dns('dns', 'DNS lookup');

  const LatencyProtocol(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static LatencyProtocol? fromWire(String? value) {
    for (final p in values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}

class LatencyResult {
  const LatencyResult({
    required this.protocol,
    required this.method,
    required this.target,
    required this.probesSent,
    required this.probesReceived,
    required this.rawRttsMs,
    required this.status,
    this.minMs,
    this.maxMs,
    this.meanMs,
    this.medianMs,
    this.p95Ms,
    this.jitterMs,
    this.packetLossPct,
    this.error,
  });

  final LatencyProtocol protocol;
  final String method;
  final String target;
  final int probesSent;
  final int probesReceived;

  /// In probe order; null = lost. Stored for recomputation.
  final List<double?> rawRttsMs;
  final TestStatus status;
  final double? minMs;
  final double? maxMs;
  final double? meanMs;
  final double? medianMs;
  final double? p95Ms;

  /// Mean |RTT(i) - RTT(i-1)| (IPDV, RFC 3393).
  final double? jitterMs;
  final double? packetLossPct;

  /// Engine reason when no probe was answered (not stored in schema v1).
  final String? error;
}

sealed class LatencyEvent {
  const LatencyEvent();
}

final class LatencyProtocolStarted extends LatencyEvent {
  const LatencyProtocolStarted(this.protocol);

  final LatencyProtocol protocol;
}

final class LatencyProbe extends LatencyEvent {
  const LatencyProbe(this.protocol, this.seq, this.rttMs);

  final LatencyProtocol protocol;
  final int seq;

  /// Null = lost.
  final double? rttMs;
}

final class LatencyCompleted extends LatencyEvent {
  const LatencyCompleted(this.result);

  final LatencyResult result;
}

/// Engine parameters; defaults are method `lat-1.0`.
class LatencyConfig {
  const LatencyConfig({
    required this.host,
    this.port = 443,
    this.protocols = LatencyProtocol.values,
    this.probes = 20,
    this.interval = const Duration(milliseconds: 200),
    this.timeout = const Duration(seconds: 2),
  });

  final String host;

  /// TCP port probed (the test server's HTTP(S) port).
  final int port;
  final List<LatencyProtocol> protocols;
  final int probes;
  final Duration interval;
  final Duration timeout;

  /// Host and port of a speed-test server base URL, or null.
  static ({String host, int port})? targetOf(String serverUrl) {
    final uri = Uri.tryParse(serverUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    return (host: uri.host, port: uri.port);
  }
}

/// A stored `latency_tests` row.
class LatencyRecord {
  const LatencyRecord({
    required this.id,
    required this.timestamp,
    required this.methodologyVersion,
    required this.result,
    this.sessionId,
    this.measurementId,
  });

  final String id;
  final DateTime timestamp;
  final String methodologyVersion;
  final LatencyResult result;
  final String? sessionId;
  final String? measurementId;
}
