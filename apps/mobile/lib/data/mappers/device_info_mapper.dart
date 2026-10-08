import 'package:opennetiq_mobile/data/mappers/channel_reader.dart';
import 'package:opennetiq_mobile/domain/entities/device_info.dart';

abstract final class DeviceInfoMapper {
  static DeviceInfo fromChannel(Object? raw) {
    final r = ChannelReader(raw, 'device info');
    return DeviceInfo(
      manufacturer: r.requireString('manufacturer'),
      model: r.requireString('model'),
      androidVersion: r.requireString('android_version'),
      apiLevel:
          r.integer('api_level') ??
          (throw const FormatException('Missing "api_level"')),
      chipset: r.string('chipset'),
      appVersion: r.string('app_version') ?? 'unknown',
    );
  }
}
