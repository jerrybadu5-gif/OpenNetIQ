import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_device_registry.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_device_info_source.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/repositories/device_repository.dart';
import 'package:opennetiq_mobile/domain/repositories/session_repository.dart';

/// Single app-wide database connection; opened lazily on first query.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.onDevice();
  ref.onDispose(db.close);
  return db;
});

final deviceInfoSourceProvider = Provider<DeviceInfoSource>(
  (ref) => const PlatformDeviceInfoSource(),
);

final deviceRegistryProvider = Provider<DeviceRegistry>(
  (ref) => DriftDeviceRegistry(ref.watch(appDatabaseProvider)),
);

final measurementStoreProvider = Provider<DriftMeasurementStore>(
  (ref) => DriftMeasurementStore(ref.watch(appDatabaseProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => ref.watch(measurementStoreProvider),
);

final sampleRepositoryProvider = Provider<SampleRepository>(
  (ref) => ref.watch(measurementStoreProvider),
);

/// All sessions, newest first.
final sessionsProvider = StreamProvider<List<MeasurementSession>>(
  (ref) => ref.watch(sessionRepositoryProvider).watchSessions(),
  isAutoDispose: true,
);
