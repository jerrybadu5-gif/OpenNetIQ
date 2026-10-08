import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

/// Feeds every radio tick (with the latest GNSS status) into the active
/// session, independent of which screen is open or whether any is (ADR-014).
/// Radio and location streams stay subscribed while a session is open,
/// including pauses, so GNSS stays warm.
final recordingPipelineProvider = Provider<void>((ref) {
  final active = ref.watch(
    recordingControllerProvider.select((s) => s.isActive),
  );
  if (!active) return;
  ref
    ..listen(locationStatusProvider, (previous, next) {})
    ..listen<AsyncValue<RadioSnapshot>>(radioSnapshotProvider, (
      previous,
      next,
    ) {
      if (next case AsyncData(:final value)) {
        final location = switch (ref.read(locationStatusProvider)) {
          AsyncData(value: final status) => status,
          _ => null,
        };
        ref
            .read(recordingControllerProvider.notifier)
            .onSnapshot(value, location);
      }
    });
});

/// Wires the recording runtime into the app-wide container: keeps the
/// pipeline alive and runs crash recovery once per process.
void startRecordingRuntime(ProviderContainer container) {
  container.listen<void>(recordingPipelineProvider, (previous, next) {});
  unawaited(container.read(startupRecoveryProvider.future));
}
