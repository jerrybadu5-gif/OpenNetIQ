import 'package:opennetiq_mobile/data/mappers/channel_reader.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';

/// Maps `org.opennetiq/speed` events (docs/features/speed-test/API.md).
abstract final class SpeedTestMapper {
  static SpeedTestEvent fromChannel(Object? value) {
    final r = ChannelReader(value, 'speed test event');
    final type = r.requireString('type');
    switch (type) {
      case 'phase':
        return SpeedTestPhaseChanged(_phase(r));
      case 'progress':
        return SpeedTestProgress(
          _phase(r),
          Duration(milliseconds: r.integer('elapsed_ms') ?? 0),
          r.decimal('mbps') ?? 0,
        );
      case 'result':
        return SpeedTestCompleted(result(r));
      default:
        throw FormatException('Unknown speed test event "$type"');
    }
  }

  static SpeedTestResult result(ChannelReader r) {
    final status = SpeedTestStatus.fromWire(r.requireString('status'));
    if (status == null) throw const FormatException('Invalid "status"');
    return SpeedTestResult(
      status: status,
      method: r.requireString('method'),
      serverHost: r.requireString('server_host'),
      streams: r.integer('streams') ?? 0,
      dnsMs: r.decimal('dns_ms'),
      tcpConnectMs: r.decimal('tcp_connect_ms'),
      download: _direction(r, 'dl'),
      upload: _direction(r, 'ul'),
      error: r.string('error'),
    );
  }

  static ThroughputResult? _direction(ChannelReader r, String prefix) {
    final mean = r.decimal('${prefix}_mean_mbps');
    if (mean == null) return null;
    return ThroughputResult(
      meanMbps: mean,
      medianMbps: r.decimal('${prefix}_median_mbps') ?? mean,
      p10Mbps: r.decimal('${prefix}_p10_mbps') ?? mean,
      p90Mbps: r.decimal('${prefix}_p90_mbps') ?? mean,
      peakMbps: r.decimal('${prefix}_peak_mbps') ?? mean,
      bytes: r.integer('${prefix}_bytes') ?? 0,
    );
  }

  static SpeedTestPhase _phase(ChannelReader r) {
    final phase = SpeedTestPhase.fromWire(r.requireString('phase'));
    if (phase == null) throw const FormatException('Invalid "phase"');
    return phase;
  }
}
