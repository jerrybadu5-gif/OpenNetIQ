import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/repositories/platform_recording_service.dart';
import 'package:opennetiq_mobile/domain/repositories/recording_service.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = PlatformRecordingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Runs once per process: a session still open from a killed process cannot
/// be resumed, so it is closed as `aborted` (and any stray service stopped).
/// Never fails; returns the number of sessions aborted.
final startupRecoveryProvider = FutureProvider<int>((ref) async {
  var aborted = 0;
  try {
    aborted = await ref.read(sessionRepositoryProvider).abortOrphanedSessions();
  } on Object {
    aborted = 0;
  }
  try {
    await ref.read(recordingServiceProvider).stop();
  } on Object {
    // Service not available (tests, no bridge): nothing to stop.
  }
  return aborted;
}, retry: (retryCount, error) => null);

/// Whether battery optimisation is off for OpenNetIQ (recommended for long
/// screen-off drive tests). Null when it cannot be determined.
final batteryOptimizationProvider = FutureProvider<bool?>(
  (ref) async {
    try {
      return await ref
          .watch(recordingServiceProvider)
          .isIgnoringBatteryOptimizations();
    } on Object {
      return null;
    }
  },
  isAutoDispose: true,
  retry: (retryCount, error) => null,
);
