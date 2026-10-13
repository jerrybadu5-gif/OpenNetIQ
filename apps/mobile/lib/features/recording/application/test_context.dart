import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

/// How long an active test waits for the first radio snapshot before running
/// without one (no permission, no telephony).
final testRadioWaitProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 3),
);

/// Where a test result is attached: the session and the start snapshot.
typedef TestLink = ({String? sessionId, String? measurementId});

/// Radio/GPS context shared by active tests (speed #19, latency #21):
/// start snapshot, RAT-change tracking and the session link.
/// The caller keeps radio and location subscribed while the test runs.
class TestContextService {
  TestContextService(this._ref);

  final Ref _ref;

  DateTime now() => _ref.read(clockProvider)();

  /// Latest radio snapshot, waiting up to [testRadioWaitProvider] while
  /// [stillRunning] holds. Null without radio data.
  Future<RadioSnapshot?> awaitRadio(bool Function() stillRunning) async {
    final deadline = now().add(_ref.read(testRadioWaitProvider));
    while (stillRunning()) {
      if (_ref.read(radioSnapshotProvider) case AsyncData(:final value)) {
        return value;
      }
      if (!now().isBefore(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  LocationStatus? latestLocation() =>
      switch (_ref.read(locationStatusProvider)) {
        AsyncData(:final value) => value,
        _ => null,
      };

  NetworkType? currentNetwork() => switch (_ref.read(radioSnapshotProvider)) {
    AsyncData(:final value) => value.networkType,
    _ => null,
  };

  /// Links to the open drive session (its latest sample), or wraps a
  /// stand-alone test in a `single_test` session named "`[label] <date>`"
  /// holding the start snapshot. Unlinked when there is no radio data.
  Future<TestLink> link({
    required String label,
    required DateTime startedAt,
    required RadioSnapshot? radio,
    required LocationStatus? location,
  }) async {
    final recording = _ref.read(recordingControllerProvider);
    final samples = _ref.read(sampleRepositoryProvider);
    final activeId = recording.sessionId;
    if (recording.isActive && activeId != null) {
      return (
        sessionId: activeId,
        measurementId: await samples.latestMeasurementId(activeId),
      );
    }
    if (radio == null) return (sessionId: null, measurementId: null);
    final info = await _ref.read(deviceInfoSourceProvider).getDeviceInfo();
    final deviceId = await _ref.read(deviceRegistryProvider).ensureDevice(info);
    final sessions = _ref.read(sessionRepositoryProvider);
    final session = await sessions.createSession(
      deviceId: deviceId,
      name: RecordingController.defaultName(startedAt.toLocal())
          .replaceFirst('Session', label),
      type: SessionType.singleTest,
      samplingIntervalMs: 1000,
    );
    await sessions.startRecording(session.id);
    final measurementId = await samples.recordSample(
      sessionId: session.id,
      radio: radio,
      location: location,
    );
    await sessions.finishRecording(session.id);
    return (sessionId: session.id, measurementId: measurementId);
  }
}

final testContextProvider = Provider<TestContextService>(
  TestContextService.new,
);
