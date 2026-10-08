import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/local/drift_speed_test_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_speed_test_engine.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/domain/repositories/speed_test_repository.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

/// `app_settings` key of the speed-test server base URL.
const String speedTestServerKey = 'speedtest.server_url';

/// Build-time default (`--dart-define=ONQ_SPEEDTEST_URL=...`), empty if unset.
const String defaultSpeedTestServer = String.fromEnvironment(
  'ONQ_SPEEDTEST_URL',
);

final speedTestEngineProvider = Provider<SpeedTestEngine>(
  (ref) => const PlatformSpeedTestEngine(),
);

final driftSpeedTestStoreProvider = Provider<DriftSpeedTestStore>(
  (ref) => DriftSpeedTestStore(ref.watch(appDatabaseProvider)),
);

final speedTestStoreProvider = Provider<SpeedTestStore>(
  (ref) => ref.watch(driftSpeedTestStoreProvider),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => ref.watch(driftSpeedTestStoreProvider),
);

/// Saved server URL, else the build-time default, else null.
final speedTestServerProvider = FutureProvider<String?>((ref) async {
  final saved = await ref
      .watch(settingsRepositoryProvider)
      .getSetting(speedTestServerKey);
  if (saved != null && saved.trim().isNotEmpty) return saved.trim();
  return defaultSpeedTestServer.isEmpty ? null : defaultSpeedTestServer;
});

/// Latest stored tests, newest first.
final speedTestHistoryProvider = StreamProvider<List<SpeedTestRecord>>(
  (ref) => ref.watch(speedTestStoreProvider).watchSpeedTests(limit: 20),
  isAutoDispose: true,
);
