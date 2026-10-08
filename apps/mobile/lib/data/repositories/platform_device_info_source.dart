import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/device_info_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/device_info.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/device_repository.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

class PlatformDeviceInfoSource implements DeviceInfoSource {
  const PlatformDeviceInfoSource({
    MethodChannel channel = MeasurementChannels.control,
  }) : this._(channel);

  const PlatformDeviceInfoSource._(this._channel);

  final MethodChannel _channel;

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        MeasurementChannels.getDeviceInfo,
      );
      return DeviceInfoMapper.fromChannel(result);
    } on PlatformException catch (e) {
      throw MeasurementException(e.code, e.message ?? e.code);
    }
  }
}
