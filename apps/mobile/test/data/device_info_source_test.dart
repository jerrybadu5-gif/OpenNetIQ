import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/repositories/platform_device_info_source.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const source = PlatformDeviceInfoSource();

  tearDown(
    () => messenger.setMockMethodCallHandler(MeasurementChannels.control, null),
  );

  test('maps the device info payload', () async {
    messenger.setMockMethodCallHandler(MeasurementChannels.control, (
      call,
    ) async {
      expect(call.method, MeasurementChannels.getDeviceInfo);
      return <String, Object?>{
        'manufacturer': 'Google',
        'model': 'Pixel 8',
        'android_version': '15',
        'api_level': 35,
        'chipset': 'Tensor G3',
        'app_version': '1.0.0',
      };
    });

    final info = await source.getDeviceInfo();
    expect(info.manufacturer, 'Google');
    expect(info.model, 'Pixel 8');
    expect(info.androidVersion, '15');
    expect(info.apiLevel, 35);
    expect(info.chipset, 'Tensor G3');
    expect(info.appVersion, '1.0.0');
  });

  test('optional fields and errors', () async {
    messenger.setMockMethodCallHandler(
      MeasurementChannels.control,
      (call) async => <String, Object?>{
        'manufacturer': 'Google',
        'model': 'Pixel 8',
        'android_version': '15',
        'api_level': 35,
      },
    );
    final info = await source.getDeviceInfo();
    expect(info.chipset, isNull);
    expect(info.appVersion, 'unknown');

    messenger.setMockMethodCallHandler(
      MeasurementChannels.control,
      (call) async => <String, Object?>{'manufacturer': 'Google'},
    );
    await expectLater(source.getDeviceInfo(), throwsFormatException);

    messenger.setMockMethodCallHandler(
      MeasurementChannels.control,
      (call) async => throw PlatformException(code: 'BOOM', message: 'x'),
    );
    await expectLater(
      source.getDeviceInfo(),
      throwsA(
        isA<MeasurementException>().having((e) => e.code, 'code', 'BOOM'),
      ),
    );
  });
}
