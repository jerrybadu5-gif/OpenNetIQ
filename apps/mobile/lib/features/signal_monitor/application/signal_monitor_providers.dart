import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/repositories/platform_radio_repository.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/repositories/radio_repository.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_history.dart';

final radioRepositoryProvider = Provider<RadioRepository>(
  (ref) => const PlatformRadioRepository(),
);

/// Sampling interval for the live dashboard (methodology default: 1 s).
final radioIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

final radioPermissionsProvider =
    AsyncNotifierProvider<RadioPermissionsController, RadioPermissions>(
      RadioPermissionsController.new,
    );

class RadioPermissionsController extends AsyncNotifier<RadioPermissions> {
  @override
  Future<RadioPermissions> build() =>
      ref.watch(radioRepositoryProvider).getPermissions();

  Future<void> request() async {
    state = const AsyncLoading<RadioPermissions>();
    state = await AsyncValue.guard(
      () => ref.read(radioRepositoryProvider).requestPermissions(),
    );
  }
}

/// Live snapshots; only subscribes to the native stream once permitted.
/// Auto-disposed so the radio stops when the screen closes (battery).
/// No automatic retry: permission errors need user action.
final radioSnapshotProvider = StreamProvider<RadioSnapshot>(
  (ref) {
    final permissions = ref.watch(radioPermissionsProvider);
    if (permissions case AsyncData(:final value) when value.canMonitor) {
      return ref
          .watch(radioRepositoryProvider)
          .watchSnapshots(interval: ref.watch(radioIntervalProvider));
    }
    return const Stream<RadioSnapshot>.empty();
  },
  isAutoDispose: true,
  retry: (retryCount, error) => null,
);

/// Rolling window of the primary cell's level for the trend chart.
final signalHistoryProvider =
    NotifierProvider<SignalHistoryController, List<SignalPoint>>(
      SignalHistoryController.new,
      isAutoDispose: true,
    );

class SignalHistoryController extends Notifier<List<SignalPoint>> {
  @override
  List<SignalPoint> build() {
    ref.listen<AsyncValue<RadioSnapshot>>(radioSnapshotProvider, (
      previous,
      next,
    ) {
      if (next case AsyncData(:final value)) {
        state = appendPoint(state, SignalPoint.fromSnapshot(value));
      }
    });
    // Seed with the snapshot already available when the history starts.
    return switch (ref.read(radioSnapshotProvider)) {
      AsyncData(:final value) => appendPoint(
        const <SignalPoint>[],
        SignalPoint.fromSnapshot(value),
      ),
      _ => const <SignalPoint>[],
    };
  }
}
