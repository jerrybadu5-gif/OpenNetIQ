import 'dart:async';

import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/domain/repositories/speed_test_repository.dart';

Map<String, Object?> resultPayload({
  String status = 'ok',
  bool withUpload = true,
  String? error,
}) => <String, Object?>{
  'type': 'result',
  'status': status,
  'method': 'http-mc-1.0',
  'server_host': 'speed.example.org',
  'streams': 4,
  'dns_ms': 12.4,
  'tcp_connect_ms': 31.0,
  'dl_mean_mbps': 48.2,
  'dl_median_mbps': 47.9,
  'dl_p10_mbps': 30.1,
  'dl_p90_mbps': 60.4,
  'dl_peak_mbps': 66.6,
  'dl_bytes': 72000000,
  'ul_mean_mbps': withUpload ? 12.1 : null,
  'ul_median_mbps': withUpload ? 12.0 : null,
  'ul_p10_mbps': withUpload ? 9.0 : null,
  'ul_p90_mbps': withUpload ? 14.0 : null,
  'ul_peak_mbps': withUpload ? 15.2 : null,
  'ul_bytes': withUpload ? 18000000 : null,
  'error': error,
};

const okResult = SpeedTestResult(
  status: SpeedTestStatus.ok,
  method: 'http-mc-1.0',
  serverHost: 'speed.example.org',
  streams: 4,
  dnsMs: 12.4,
  tcpConnectMs: 31,
  download: ThroughputResult(
    meanMbps: 48.2,
    medianMbps: 47.9,
    p10Mbps: 30.1,
    p90Mbps: 60.4,
    peakMbps: 66.6,
    bytes: 72000000,
  ),
  upload: ThroughputResult(
    meanMbps: 12.1,
    medianMbps: 12,
    p10Mbps: 9,
    p90Mbps: 14,
    peakMbps: 15.2,
    bytes: 18000000,
  ),
);

/// Engine driven by the test through [events].
class FakeSpeedTestEngine implements SpeedTestEngine {
  StreamController<SpeedTestEvent>? _controller;
  final configs = <SpeedTestConfig>[];
  bool cancelled = false;

  @override
  Stream<SpeedTestEvent> run(SpeedTestConfig config) {
    configs.add(config);
    final controller = StreamController<SpeedTestEvent>(
      onCancel: () => cancelled = true,
    );
    _controller = controller;
    return controller.stream;
  }

  bool get running => _controller != null;

  void emit(SpeedTestEvent event) => _controller!.add(event);

  void fail(Object error) => _controller!.addError(error);

  Future<void> finish([SpeedTestResult? result]) async {
    final c = _controller!;
    if (result != null) c.add(SpeedTestCompleted(result));
    await c.close();
  }
}
