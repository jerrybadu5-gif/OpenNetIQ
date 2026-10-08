import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/speed_test_mapper.dart';
import 'package:opennetiq_mobile/data/repositories/platform_speed_test_engine.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

import '../fixtures/speed_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const engine = PlatformSpeedTestEngine();

  tearDown(
    () => messenger.setMockStreamHandler(MeasurementChannels.speed, null),
  );

  group('mapper', () {
    test('maps phase, progress and a full result', () {
      final phase = SpeedTestMapper.fromChannel({
        'type': 'phase',
        'phase': 'download',
      });
      expect((phase as SpeedTestPhaseChanged).phase, SpeedTestPhase.download);

      final progress = SpeedTestMapper.fromChannel({
        'type': 'progress',
        'phase': 'upload',
        'elapsed_ms': 2500,
        'mbps': 12,
      });
      progress as SpeedTestProgress;
      expect(progress.phase, SpeedTestPhase.upload);
      expect(progress.elapsed, const Duration(milliseconds: 2500));
      expect(progress.mbps, 12.0);

      final r = (SpeedTestMapper.fromChannel(
        resultPayload(),
      ) as SpeedTestCompleted).result;
      expect(r.status, SpeedTestStatus.ok);
      expect(r.method, 'http-mc-1.0');
      expect(r.serverHost, 'speed.example.org');
      expect(r.streams, 4);
      expect(r.dnsMs, 12.4);
      expect(r.tcpConnectMs, 31.0);
      expect(r.download!.medianMbps, 47.9);
      expect(r.download!.peakMbps, 66.6);
      expect(r.download!.bytes, 72000000);
      expect(r.upload!.p10Mbps, 9.0);
      expect(r.error, isNull);
    });

    test('missing direction and error text', () {
      final r = (SpeedTestMapper.fromChannel(
        resultPayload(
          status: 'partial',
          withUpload: false,
          error: 'upload: HTTP 500',
        ),
      ) as SpeedTestCompleted).result;
      expect(r.status, SpeedTestStatus.partial);
      expect(r.upload, isNull);
      expect(r.error, 'upload: HTTP 500');
    });

    test('rejects unknown types, phases and statuses', () {
      for (final bad in <Object?>[
        {'type': 'nope'},
        {'type': 'phase', 'phase': 'warp'},
        resultPayload(status: 'cancelled'),
        'not a map',
      ]) {
        expect(
          () => SpeedTestMapper.fromChannel(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  test('sends the configuration and streams events', () async {
    Object? args;
    messenger.setMockStreamHandler(
      MeasurementChannels.speed,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          args = arguments;
          events.success({'type': 'phase', 'phase': 'dns'});
          events.success({
            'type': 'progress',
            'phase': 'download',
            'elapsed_ms': 100,
            'mbps': 5.5,
          });
          events.success(resultPayload());
          events.endOfStream();
        },
      ),
    );

    final events = await engine
        .run(const SpeedTestConfig(serverUrl: 'https://speed.example.org/'))
        .toList();

    expect(args, {
      'server_url': 'https://speed.example.org/',
      'streams': 4,
      'direction_ms': 12000,
    });
    expect(events, hasLength(3));
    expect(events.last, isA<SpeedTestCompleted>());
  });

  test('native errors become MeasurementException', () async {
    messenger.setMockStreamHandler(
      MeasurementChannels.speed,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.error(
            code: 'INVALID_CONFIG',
            message: 'Server URL has no host',
          );
          events.endOfStream();
        },
      ),
    );
    await expectLater(
      engine.run(const SpeedTestConfig(serverUrl: 'http://')),
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
      MeasurementChannels.speed,
      MockStreamHandler.inline(
        onListen: (arguments, events) =>
            events.success({'type': 'phase', 'phase': 'dns'}),
        onCancel: (arguments) => cancelled = true,
      ),
    );
    final sub = engine
        .run(const SpeedTestConfig(serverUrl: 'https://h/'))
        .listen((_) {});
    await pumpEventQueue();
    await sub.cancel();
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });
}
