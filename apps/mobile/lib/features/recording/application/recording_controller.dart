import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

enum RecordingPhase { idle, starting, recording, stopping }

class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.sessionId,
    this.lastSessionId,
    this.failedSamples = 0,
    this.error,
  });

  final RecordingPhase phase;

  /// Session being recorded (null when idle).
  final String? sessionId;

  /// Most recently finished session.
  final String? lastSessionId;

  /// Ticks that could not be stored (shown to the user, never silent).
  final int failedSamples;
  final String? error;

  bool get isRecording => phase == RecordingPhase.recording;
}

/// Foreground recording of radio + location ticks into a session
/// (issue #16). Background recording arrives with the foreground service (#17).
class RecordingController extends Notifier<RecordingState> {
  Future<void> _writes = Future<void>.value();

  @override
  RecordingState build() => const RecordingState();

  /// Default session name, local time, e.g. `Session 2026-10-08 14:36`.
  static String defaultName(DateTime local) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Session ${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> start({SessionType type = SessionType.drive}) async {
    if (state.phase != RecordingPhase.idle) return;
    state = RecordingState(
      phase: RecordingPhase.starting,
      lastSessionId: state.lastSessionId,
    );
    try {
      final info = await ref.read(deviceInfoSourceProvider).getDeviceInfo();
      final deviceId = await ref
          .read(deviceRegistryProvider)
          .ensureDevice(info);
      final sessions = ref.read(sessionRepositoryProvider);
      final session = await sessions.createSession(
        deviceId: deviceId,
        name: defaultName(DateTime.now()),
        type: type,
        samplingIntervalMs: ref.read(radioIntervalProvider).inMilliseconds,
      );
      await sessions.startRecording(session.id);
      state = RecordingState(
        phase: RecordingPhase.recording,
        sessionId: session.id,
        lastSessionId: state.lastSessionId,
      );
    } on Object catch (e) {
      state = RecordingState(
        lastSessionId: state.lastSessionId,
        error: 'Could not start recording: $e',
      );
    }
  }

  /// Stores one tick. Writes are queued so samples keep their order.
  void onSnapshot(RadioSnapshot radio, LocationStatus? location) {
    final sessionId = state.sessionId;
    if (!state.isRecording || sessionId == null) return;
    final samples = ref.read(sampleRepositoryProvider);
    _writes = _writes.then((_) async {
      try {
        await samples.recordSample(
          sessionId: sessionId,
          radio: radio,
          location: location,
        );
      } on Object catch (e) {
        state = RecordingState(
          phase: state.phase,
          sessionId: state.sessionId,
          lastSessionId: state.lastSessionId,
          failedSamples: state.failedSamples + 1,
          error: 'Sample not stored: $e',
        );
      }
    });
  }

  Future<void> stop() async {
    final sessionId = state.sessionId;
    if (!state.isRecording || sessionId == null) return;
    state = RecordingState(
      phase: RecordingPhase.stopping,
      sessionId: sessionId,
      lastSessionId: state.lastSessionId,
      failedSamples: state.failedSamples,
      error: state.error,
    );
    await _writes;
    await ref.read(sessionRepositoryProvider).finishRecording(sessionId);
    state = RecordingState(
      lastSessionId: sessionId,
      failedSamples: state.failedSamples,
      error: state.error,
    );
  }
}

final recordingControllerProvider =
    NotifierProvider<RecordingController, RecordingState>(
      RecordingController.new,
    );

/// Live row of the session being recorded (for the sample counter).
final activeSessionProvider = StreamProvider<MeasurementSession?>((ref) {
  final id = ref.watch(recordingControllerProvider.select((s) => s.sessionId));
  if (id == null) return Stream<MeasurementSession?>.value(null);
  return ref.watch(sessionRepositoryProvider).watchSession(id);
}, isAutoDispose: true);
