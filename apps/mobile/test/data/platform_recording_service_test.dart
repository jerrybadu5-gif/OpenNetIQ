import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/repositories/platform_recording_service.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/recording_service.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  late PlatformRecordingService service;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    service = PlatformRecordingService();
  });
  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(MeasurementChannels.control, null);
  });

  void mockNative(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(MeasurementChannels.control, (
      call,
    ) async {
      calls.add(call);
      return handler(call);
    });
  }

  /// Simulates a call from Kotlin to Dart; returns Dart's decoded reply.
  Future<Object?> nativeCalls(String method, [Object? args]) async {
    Object? reply;
    await messenger.handlePlatformMessage(
      MeasurementChannels.controlName,
      codec.encodeMethodCall(MethodCall(method, args)),
      (data) {
        if (data != null) reply = codec.decodeEnvelope(data);
      },
    );
    return reply;
  }

  test('start, update and stop send title and text', () async {
    mockNative((call) => null);

    await service.start(title: 'Recording A', text: 'Starting...');
    await service.update(title: 'Recording A', text: '10 samples');
    await service.stop();

    expect(calls.map((c) => c.method), [
      MeasurementChannels.startRecordingService,
      MeasurementChannels.updateRecordingService,
      MeasurementChannels.stopRecordingService,
    ]);
    expect(calls.first.arguments, {
      'title': 'Recording A',
      'text': 'Starting...',
    });
    expect(calls[1].arguments, {'title': 'Recording A', 'text': '10 samples'});
  });

  test('platform errors become MeasurementException', () async {
    mockNative(
      (call) => throw PlatformException(
        code: 'SERVICE_UNAVAILABLE',
        message: 'not visible',
      ),
    );
    await expectLater(
      service.start(title: 't', text: 'x'),
      throwsA(
        isA<MeasurementException>().having(
          (e) => e.code,
          'code',
          'SERVICE_UNAVAILABLE',
        ),
      ),
    );
    await expectLater(
      service.isIgnoringBatteryOptimizations(),
      throwsA(isA<MeasurementException>()),
    );
    await expectLater(
      service.openBatterySettings(),
      throwsA(isA<MeasurementException>()),
    );
  });

  test('battery optimisation status and settings', () async {
    mockNative(
      (call) => switch (call.method) {
        MeasurementChannels.getBatteryOptimization => {'ignoring': false},
        MeasurementChannels.openBatterySettings => true,
        _ => null,
      },
    );
    expect(await service.isIgnoringBatteryOptimizations(), isFalse);
    expect(await service.openBatterySettings(), isTrue);
  });

  test('stop request is taken only while someone listens', () async {
    expect(await nativeCalls(MeasurementChannels.onStopRequested), isFalse);

    final events = <RecordingServiceEvent>[];
    final sub = service.events.listen(events.add);
    expect(await nativeCalls(MeasurementChannels.onStopRequested), isTrue);
    await pumpEventQueue();
    expect(events.single, isA<RecordingStopRequested>());
    await sub.cancel();
  });

  test('service errors are forwarded, with or without details', () async {
    final events = <RecordingServiceEvent>[];
    final sub = service.events.listen(events.add);

    await nativeCalls(MeasurementChannels.onServiceError, {
      'code': 'FOREGROUND_DENIED',
      'message': 'location revoked',
    });
    await nativeCalls(MeasurementChannels.onServiceError);
    await pumpEventQueue();

    final first = events.first as RecordingServiceFailed;
    expect(first.code, 'FOREGROUND_DENIED');
    expect(first.message, 'location revoked');
    final second = events.last as RecordingServiceFailed;
    expect(second.code, 'UNKNOWN');
    await sub.cancel();
  });

  test('unknown native calls are rejected', () async {
    final reply = await nativeCalls('somethingElse');
    expect(reply, isNull);
  });
}
