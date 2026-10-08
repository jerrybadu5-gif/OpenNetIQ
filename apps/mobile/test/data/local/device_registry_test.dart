import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_device_registry.dart';
import 'package:opennetiq_mobile/domain/entities/device_info.dart';

import '../../fixtures/db_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('registers once with a random id and keeps it', () async {
    final registry = DriftDeviceRegistry(db, newId: sequentialIds('dev'));
    final first = await registry.ensureDevice(testDevice);
    final second = await registry.ensureDevice(testDevice);

    expect(first, 'dev-00000');
    expect(second, first);
    final devices = await db.select(db.devices).get();
    expect(devices, hasLength(1));
    expect(devices.single.model, 'SM-A546E');
    expect(devices.single.chipset, 's5e8835');
  });

  test('updates device details on app upgrade, keeps created_at', () async {
    var now = DateTime.utc(2026, 10, 8);
    final registry = DriftDeviceRegistry(db, now: () => now);
    final id = await registry.ensureDevice(testDevice);

    now = DateTime.utc(2026, 11, 1);
    await registry.ensureDevice(
      const DeviceInfo(
        manufacturer: 'Samsung',
        model: 'SM-A546E',
        androidVersion: '15',
        apiLevel: 35,
        appVersion: '1.1.0',
      ),
    );

    final row = await (db.select(
      db.devices,
    )..where((t) => t.deviceId.equals(id))).getSingle();
    expect(row.appVersion, '1.1.0');
    expect(row.apiLevel, 35);
    expect(row.createdAt, '2026-10-08T00:00:00.000Z');
    expect(row.updatedAt, '2026-11-01T00:00:00.000Z');
  });
}
