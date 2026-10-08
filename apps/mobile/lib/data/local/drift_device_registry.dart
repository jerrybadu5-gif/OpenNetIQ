import 'package:drift/drift.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/device_info.dart';
import 'package:opennetiq_mobile/domain/repositories/device_repository.dart';

class DriftDeviceRegistry implements DeviceRegistry {
  DriftDeviceRegistry(
    this._db, {
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? uuid7;

  /// `app_settings` key holding this install's random device id.
  static const String deviceIdKey = 'device_id';

  final AppDatabase _db;
  final DateTime Function() _now;
  final String Function() _newId;

  @override
  Future<String> ensureDevice(DeviceInfo info) => _db.transaction(() async {
    final now = formatUtc(_now());
    final setting = await (_db.select(
      _db.appSettings,
    )..where((t) => t.settingKey.equals(deviceIdKey))).getSingleOrNull();
    final deviceId = setting?.settingValue ?? _newId();
    if (setting == null) {
      await _db
          .into(_db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              settingKey: deviceIdKey,
              settingValue: deviceId,
              updatedAt: now,
            ),
          );
    }
    final existing = await (_db.select(
      _db.devices,
    )..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    final row = DevicesCompanion(
      deviceId: Value(deviceId),
      manufacturer: Value(info.manufacturer),
      model: Value(info.model),
      androidVersion: Value(info.androidVersion),
      apiLevel: Value(info.apiLevel),
      chipset: Value(info.chipset),
      appVersion: Value(info.appVersion),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
    );
    await _db.into(_db.devices).insertOnConflictUpdate(row);
    return deviceId;
  });
}
