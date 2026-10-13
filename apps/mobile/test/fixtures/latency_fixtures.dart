import 'dart:async';

import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/domain/repositories/latency_test_repository.dart';

Map<String, Object?> latencyResultPayload({
  String protocol = 'tcp',
  String status = 'ok',
  List<Object?> rtts = const [20.0, 30.0, null, 25.0, 40.0],
  String? error,
}) => <String, Object?>{
  'type': 'result',
  'protocol': protocol,
  'method': 'lat-1.0',
  'target': 'speed.example.org:443',
  'probes_sent': rtts.length,
  'probes_received': rtts.where((r) => r != null).length,
  'min_ms': 20.0,
  'max_ms': 40.0,
  'mean_ms': 28.75,
  'median_ms': 27.4,
  'p95_ms': 40.0,
  'jitter_ms': 12.6,
  'packet_loss_pct': 20.0,
  'raw_rtts_ms': rtts,
  'status': status,
  'error': error,
};

LatencyResult latencyResult({
  LatencyProtocol protocol = LatencyProtocol.tcp,
  TestStatus status = TestStatus.ok,
  double? medianMs = 27.4,
  double? lossPct = 20,
}) => LatencyResult(
  protocol: protocol,
  method: 'lat-1.0',
  target: 'speed.example.org:443',
  probesSent: 5,
  probesReceived: 4,
  rawRttsMs: const [20.0, 30.0, null, 25.0, 40.0],
  status: status,
  minMs: 20,
  maxMs: 40,
  meanMs: 28.75,
  medianMs: medianMs,
  p95Ms: 40,
  jitterMs: 12.6,
  packetLossPct: lossPct,
);

/// Engine driven by the test.
class FakeLatencyEngine implements LatencyEngine {
  StreamController<LatencyEvent>? _controller;
  final configs = <LatencyConfig>[];
  bool cancelled = false;

  @override
  Stream<LatencyEvent> run(LatencyConfig config) {
    configs.add(config);
    final c = StreamController<LatencyEvent>(onCancel: () => cancelled = true);
    _controller = c;
    return c.stream;
  }

  bool get running => _controller != null;

  void emit(LatencyEvent event) => _controller!.add(event);

  void fail(Object error) => _controller!.addError(error);

  Future<void> finish() => _controller!.close();
}
