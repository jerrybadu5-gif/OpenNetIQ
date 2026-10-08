import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/repositories/platform_radio_repository.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/errors/radio_exception.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

import '../fixtures/radio_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const repository = PlatformRadioRepository();

  tearDown(() {
    messenger.setMockStreamHandler(MeasurementChannels.radio, null);
    messenger.setMockMethodCallHandler(MeasurementChannels.control, null);
  });

  group('watchSnapshots', () {
    test('passes the interval and maps events', () async {
      Object? listenArguments;
      messenger.setMockStreamHandler(
        MeasurementChannels.radio,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            listenArguments = arguments;
            events.success(snapshotPayload(networkType: 'NR_NSA'));
            events.endOfStream();
          },
        ),
      );

      final snapshots = await repository
          .watchSnapshots(interval: const Duration(seconds: 2))
          .toList();

      expect(listenArguments, {'interval_ms': 2000});
      expect(snapshots, hasLength(1));
      expect(snapshots.single.networkType, NetworkType.nrNsa);
      expect(snapshots.single.operatorName, 'Digicel PNG');
    });

    test('translates native errors to RadioException', () async {
      messenger.setMockStreamHandler(
        MeasurementChannels.radio,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.error(
              code: RadioException.permissionDenied,
              message: 'Precise location permission is required',
            );
            events.endOfStream();
          },
        ),
      );

      await expectLater(
        repository.watchSnapshots(),
        emitsError(
          isA<RadioException>()
              .having((e) => e.code, 'code', RadioException.permissionDenied)
              .having((e) => e.message, 'message', contains('location')),
        ),
      );
    });

    test('surfaces malformed payloads as FormatException', () async {
      messenger.setMockStreamHandler(
        MeasurementChannels.radio,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success(<String, Object?>{'cells': <Object?>[]});
            events.endOfStream();
          },
        ),
      );

      await expectLater(
        repository.watchSnapshots(),
        emitsError(isA<FormatException>()),
      );
    });
  });

  group('permissions', () {
    test(
      'getPermissions and requestPermissions call the control channel',
      () async {
        final calls = <String>[];
        messenger.setMockMethodCallHandler(MeasurementChannels.control, (
          call,
        ) async {
          calls.add(call.method);
          return <String, Object?>{
            'location': call.method == MeasurementChannels.requestPermissions,
            'phone_state': false,
            'has_telephony': true,
            'api_level': 34,
          };
        });

        final before = await repository.getPermissions();
        final after = await repository.requestPermissions();

        expect(calls, ['getPermissionStatus', 'requestPermissions']);
        expect(before.canMonitor, isFalse);
        expect(after.canMonitor, isTrue);
        expect(after.apiLevel, 34);
      },
    );

    test('translates PlatformException to RadioException', () async {
      messenger.setMockMethodCallHandler(
        MeasurementChannels.control,
        (call) async => throw PlatformException(
          code: 'IN_PROGRESS',
          message: 'A permission request is already showing.',
        ),
      );

      await expectLater(
        repository.requestPermissions(),
        throwsA(
          isA<RadioException>().having((e) => e.code, 'code', 'IN_PROGRESS'),
        ),
      );
    });

    test('null status payload is a FormatException', () async {
      messenger.setMockMethodCallHandler(
        MeasurementChannels.control,
        (call) async => null,
      );

      await expectLater(repository.getPermissions(), throwsFormatException);
    });
  });
}
