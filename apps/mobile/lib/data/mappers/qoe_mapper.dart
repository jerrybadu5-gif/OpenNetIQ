import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';

/// Native result map (QoeBridge) -> [QoeResult].
abstract final class QoeMapper {
  static double? _d(Object? v) => v is num ? v.toDouble() : null;
  static int? _i(Object? v) => v is num ? v.toInt() : null;

  static QoeResult fromMap(
    QoeKind kind,
    String label,
    String target,
    Map<Object?, Object?> m,
  ) {
    final error = m['error'] as String?;
    final startDelay = _d(m['start_delay_ms']);
    final status = switch (kind) {
      QoeKind.video when startDelay == null => TestStatus.failed,
      QoeKind.video when error != null => TestStatus.partial,
      _ when error != null => TestStatus.failed,
      _ => TestStatus.ok,
    };
    return QoeResult(
      kind: kind,
      label: label,
      target: target,
      status: status,
      error: error,
      totalMs: _d(m['total_ms']),
      dnsMs: _d(m['dns_ms']),
      connectMs: _d(m['connect_ms']),
      tlsMs: _d(m['tls_ms']),
      ttfbMs: _d(m['ttfb_ms']),
      domMs: _d(m['dom_ms']),
      httpStatus: _i(m['http_status']),
      startDelayMs: startDelay,
      rebufferCount: _i(m['rebuffer_count']),
      rebufferMs: _d(m['rebuffer_ms']),
      playedMs: _d(m['played_ms']),
      bitrateKbps: _d(m['bitrate_kbps']),
      resolution: m['resolution'] as String?,
      bytes: _i(m['bytes']),
      rateMbps: _d(m['rate_mbps']),
      direction: m['direction'] as String?,
      protocol:
          m['protocol'] as String? ?? (kind == QoeKind.file ? 'http' : null),
    );
  }
}
