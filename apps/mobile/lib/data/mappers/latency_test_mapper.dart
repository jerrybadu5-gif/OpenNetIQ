import 'package:opennetiq_mobile/data/mappers/channel_reader.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';

/// Maps `org.opennetiq/latency` events (docs/features/latency-test/API.md).
abstract final class LatencyTestMapper {
  static LatencyEvent fromChannel(Object? value) {
    final r = ChannelReader(value, 'latency event');
    final type = r.requireString('type');
    switch (type) {
      case 'protocol':
        return LatencyProtocolStarted(_protocol(r));
      case 'probe':
        return LatencyProbe(
          _protocol(r),
          r.integer('seq') ?? 0,
          r.decimal('rtt_ms'),
        );
      case 'result':
        return LatencyCompleted(result(r));
      default:
        throw FormatException('Unknown latency event "$type"');
    }
  }

  static LatencyResult result(ChannelReader r) {
    final status = TestStatus.fromWire(r.requireString('status'));
    if (status == null) throw const FormatException('Invalid "status"');
    return LatencyResult(
      protocol: _protocol(r),
      method: r.requireString('method'),
      target: r.requireString('target'),
      probesSent: r.integer('probes_sent') ?? 0,
      probesReceived: r.integer('probes_received') ?? 0,
      rawRttsMs: rtts(r.list('raw_rtts_ms')),
      status: status,
      minMs: r.decimal('min_ms'),
      maxMs: r.decimal('max_ms'),
      meanMs: r.decimal('mean_ms'),
      medianMs: r.decimal('median_ms'),
      p95Ms: r.decimal('p95_ms'),
      jitterMs: r.decimal('jitter_ms'),
      packetLossPct: r.decimal('packet_loss_pct'),
      error: r.string('error'),
    );
  }

  /// Numbers and nulls only.
  static List<double?> rtts(List<Object?> raw) => [
    for (final v in raw)
      switch (v) {
        null => null,
        final num n => n.toDouble(),
        _ => throw const FormatException('Invalid "raw_rtts_ms"'),
      },
  ];

  static LatencyProtocol _protocol(ChannelReader r) {
    final p = LatencyProtocol.fromWire(r.requireString('protocol'));
    if (p == null) throw const FormatException('Invalid "protocol"');
    return p;
  }
}
