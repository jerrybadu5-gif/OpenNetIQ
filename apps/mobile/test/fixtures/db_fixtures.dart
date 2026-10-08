import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/device_info.dart';
import 'package:opennetiq_mobile/domain/repositories/device_repository.dart';

/// Fresh in-memory database per test.
AppDatabase memoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

const testDevice = DeviceInfo(
  manufacturer: 'Samsung',
  model: 'SM-A546E',
  androidVersion: '14',
  apiLevel: 34,
  chipset: 's5e8835',
  appVersion: '1.0.0',
);

class FakeDeviceInfoSource implements DeviceInfoSource {
  FakeDeviceInfoSource({this.info = testDevice, this.error});

  final DeviceInfo info;
  final Object? error;

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final e = error;
    if (e != null) throw e;
    return info;
  }
}

/// Deterministic, strictly increasing ids for assertions.
String Function() sequentialIds([String prefix = 'id']) {
  var n = 0;
  return () => '$prefix-${(n++).toString().padLeft(5, '0')}';
}
