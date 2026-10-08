import 'package:opennetiq_mobile/domain/entities/device_info.dart';

/// Reads device details from the platform.
abstract interface class DeviceInfoSource {
  Future<DeviceInfo> getDeviceInfo();
}

/// Registers this install as a `devices` row with a random UUIDv7 id
/// (never IMEI) and returns the id. Idempotent.
abstract interface class DeviceRegistry {
  Future<String> ensureDevice(DeviceInfo info);
}
