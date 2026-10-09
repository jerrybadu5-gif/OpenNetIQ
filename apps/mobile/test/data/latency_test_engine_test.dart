import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/latency_test_mapper.dart';
import 'package:opennetiq_mobile/data/repositories/platform_latency_engine.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

import '../fixtures/latency_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const engine = PlatformLatencyEngine();

  tearDown(
    () => messenger.setMockStreamHandler(MeasurementChannels.latency, null),
  );

  group('mapper', () {
    test('maps protocol, probe and result events', () {
      final start = LatencyTestMapper.fromChannel({
        'type': 'protocol',
        'protocol': 'icmp',
      });
      expect((start as LatencyProtocolStarted).protocol, LatencyProtocol.icmp);

      final probe = LatencyTestMapper.fromChannel({
        'type': 'probe',
        'protocol': 'dns',
        'seq': 3,
        'rtt_ms': null,
      });
      probe as LatencyProbe;
      expect(probe.protocol, LatencyProtocol.dns);
      expect(probe.seq, 3);
      expect(probe.rttMs, isNull);

      final r =
          (LatencyTestMapper.fromChannel(latencyResultPayload())
                  as LatencyCompleted)
              .result;
      expect(r.protocol, LatencyProtocol.tcp);
      expect(r.method, 'lat-1.0');
      expect(r.target, 'speed.example.org:443');
      expect(r.probesSent, 5);
      expect(r.probesReceived, 4);
      expect(r.rawRttsMs, [20.0, 30.0, null, 25.0, 40.0]);
      expect(r.medianMs, 27.4);
      expect(r.jitterMs, 12.6);
      expect(r.packetLossPct, 20.0);
      expect(r.status, TestStatus.ok);
    });

    test('integer RTTs and failure reasons', () {
      final r =
          (LatencyTestMapper.fromChannel(
                    latencyResultPayload(
                      protocol: 'icmp',
                      status: 'failed',
                      rtts: [null, 7],
                      error: 'ping: unknown host',
                    ),
                  )
                  as LatencyCompleted)
              .result;
      expect(r.rawRttsMs, [null, 7.0]);
      expect(r.status, TestStatus.failed);
      expect(r.error, 'ping: unknown host');
    });

    test('rejects unknown types, protocols, statuses and RTT values', () {
      for (final bad in <Object?>[
        {'type': 'nope'},
        {'type': 'protocol', 'protocol': 'udp'},
        latencyResultPayload(status: 'cancelled'),
        latencyResultPayload(rtts: ['x']),
        42,
      ]) {
        expect(
          () => LatencyTestMapper.fromChannel(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  test('server URL gives the probe target', () {
    expect(
      LatencyConfig.targetOf('https://speed.example.org/backend/'),
      (host: 'speed.example.org', port: 443),
    );
    expect(
      LatencyConfig.targetOf('http://192.168.1.10:8080/backend/'),
      (host: '192.168.1.10', port: 8080),
    );
    expect(LatencyConfig.targetOf('ftp://h/'), isNull);
    expect(LatencyConfig.targetOf('nonsense'), isNull);
  });

  test('sends the configuration and streams events', () async {
    Object? args;
    messenger.setMockStreamHandler(
      MeasurementChannels.latency,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          args = arguments;
          events.success({'type': 'protocol', 'protocol': 'tcp'});
          events.success({
            'type': 'probe',
            'protocol': 'tcp',
            'seq': 1,
            'rtt_ms': 21.5,
          });
          events.success(latencyResultPayload());
          events.endOfStream();
        },
      ),
    );

    final events = await engine
        .run(const LatencyConfig(host: 'speed.example.org', port: 8443))
        .toList();

    expect(args, {
      'host': 'speed.example.org',
      'port': 8443,
      'protocols': ['icmp', 'tcp', 'dns'],
      'probes': 20,
      'interval_ms': 200,
      'timeout_ms': 2000,
    });
    expect(events, hasLength(3));
    expect(events.last, isA<LatencyCompleted>());
  });

  test('native errors become MeasurementException', () async {
    messenger.setMockStreamHandler(
      MeasurementChannels.latency,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.error(code: 'INVALID_CONFIG', message: 'Invalid host');
          events.endOfStream();
        },
      ),
    );
    await expectLater(
      engine.run(const LatencyConfig(host: 'bad host')),
      emitsError(
        isA<MeasurementException>().having(
          (e) => e.code,
          'code',
          'INVALID_CONFIG',
        ),
      ),
    );
  });

  test('cancelling the subscription cancels the native test', () async {
    var cancelled = false;
    messenger.setMockStreamHandler(
      MeasurementChannels.latency,
      MockStreamHandler.inline(
        onListen: (arguments, events) =>
            events.success({'type': 'protocol', 'protocol': 'icmp'}),
        onCancel: (arguments) => cancelled = true,
      ),
    );
    final sub = engine
        .run(const LatencyConfig(host: 'h'))
        .listen((_) {});
    await pumpEventQueue();
    await sub.cancel();
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });
}
