import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/core/methodology.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

class SpeedTestState {
  const SpeedTestState({
    this.running = false,
    this.phase,
    this.liveMbps,
    this.downloadCurve = const [],
    this.uploadCurve = const [],
    this.result,
    this.ratChanged = false,
    this.error,
  });

  final bool running;
  final SpeedTestPhase? phase;

  /// Rate over the last second of the current phase.
  final double? liveMbps;
  final List<SpeedTestProgress> downloadCurve;
  final List<SpeedTestProgress> uploadCurve;
  final SpeedTestResult? result;
  final bool ratChanged;
  final String? error;

  SpeedTestState progressed({
    SpeedTestPhase? phase,
    double? liveMbps,
    List<SpeedTestProgress>? downloadCurve,
    List<SpeedTestProgress>? uploadCurve,
  }) => SpeedTestState(
    running: running,
    phase: phase ?? this.phase,
    liveMbps: liveMbps ?? this.liveMbps,
    downloadCurve: downloadCurve ?? this.downloadCurve,
    uploadCurve: uploadCurve ?? this.uploadCurve,
  );
}

/// Runs one speed test (issue #19): native engine, radio snapshot at start,
/// RAT-change check, persistence with methodology version.
class SpeedTestController extends Notifier<SpeedTestState> {
  StreamSubscription<SpeedTestEvent>? _subscription;
  Completer<SpeedTestResult?>? _outcome;

  /// How long to wait for the first radio snapshot before testing anyway.
  static const Duration radioWait = Duration(seconds: 3);

  @override
  SpeedTestState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const SpeedTestState();
  }

  DateTime _now() => ref.read(clockProvider)();

  Future<void> saveServer(String url) async {
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(speedTestServerKey, url.trim());
    ref.invalidate(speedTestServerProvider);
  }

  Future<void> start() async {
    if (state.running) return;
    final String? url;
    try {
      url = await ref.read(speedTestServerProvider.future);
    } on Object catch (e) {
      state = SpeedTestState(error: 'Could not read settings: $e');
      return;
    }
    if (url == null) {
      state = const SpeedTestState(error: 'Set a speed-test server URL first.');
      return;
    }
    state = const SpeedTestState(running: true);
    final startedAt = _now();
    final startRadio = await _awaitRadio();
    if (!state.running) return; // cancelled while waiting
    final startLocation = _latestLocation();
    final networks = <NetworkType>{?startRadio?.networkType};

    final outcome = Completer<SpeedTestResult?>();
    _outcome = outcome;
    _subscription = ref
        .read(speedTestEngineProvider)
        .run(SpeedTestConfig(serverUrl: url))
        .listen(
          (event) => _onEvent(event, outcome, networks),
          onError: (Object e) {
            if (!outcome.isCompleted) outcome.completeError(e);
          },
          onDone: () {
            if (!outcome.isCompleted) outcome.complete(null);
          },
        );

    final SpeedTestResult? result;
    try {
      result = await outcome.future;
    } on Object catch (e) {
      _subscription = null;
      state = SpeedTestState(error: 'Speed test failed: $e');
      return;
    }
    _subscription = null;
    _outcome = null;
    if (result == null) {
      if (state.running) {
        state = const SpeedTestState(
          error: 'Speed test ended without a result.',
        );
      }
      return; // cancelled: nothing stored
    }
    _noteNetwork(networks);
    final ratChanged = networks.length > 1;
    String? error;
    try {
      await _persist(
        url: url,
        result: result,
        startedAt: startedAt,
        startRadio: startRadio,
        startLocation: startLocation,
        ratChanged: ratChanged,
      );
    } on Object catch (e) {
      error = 'Result not saved: $e';
    }
    state = SpeedTestState(
      result: result,
      ratChanged: ratChanged,
      downloadCurve: state.downloadCurve,
      uploadCurve: state.uploadCurve,
      error: error,
    );
  }

  /// Stops the test; nothing is stored.
  Future<void> cancel() async {
    if (!state.running) return;
    final subscription = _subscription;
    _subscription = null;
    state = const SpeedTestState();
    final outcome = _outcome;
    if (outcome != null && !outcome.isCompleted) outcome.complete(null);
    await subscription?.cancel();
  }

  void _onEvent(
    SpeedTestEvent event,
    Completer<SpeedTestResult?> outcome,
    Set<NetworkType> networks,
  ) {
    if (!state.running) return;
    switch (event) {
      case SpeedTestPhaseChanged(:final phase):
        _noteNetwork(networks);
        state = state.progressed(phase: phase);
      case final SpeedTestProgress p:
        state = p.phase == SpeedTestPhase.upload
            ? state.progressed(
                phase: p.phase,
                liveMbps: p.mbps,
                uploadCurve: [...state.uploadCurve, p],
              )
            : state.progressed(
                phase: p.phase,
                liveMbps: p.mbps,
                downloadCurve: [...state.downloadCurve, p],
              );
      case SpeedTestCompleted(:final result):
        if (!outcome.isCompleted) outcome.complete(result);
    }
  }

  Future<RadioSnapshot?> _awaitRadio() async {
    final deadline = _now().add(radioWait);
    while (state.running) {
      if (ref.read(radioSnapshotProvider) case AsyncData(:final value)) {
        return value;
      }
      if (!_now().isBefore(deadline)) return null;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  LocationStatus? _latestLocation() =>
      switch (ref.read(locationStatusProvider)) {
        AsyncData(:final value) => value,
        _ => null,
      };

  void _noteNetwork(Set<NetworkType> networks) {
    if (ref.read(radioSnapshotProvider) case AsyncData(:final value)) {
      networks.add(value.networkType);
    }
  }

  /// Links the test to the open drive session, or wraps a stand-alone test
  /// in a `single_test` session holding the start snapshot.
  Future<void> _persist({
    required String url,
    required SpeedTestResult result,
    required DateTime startedAt,
    required RadioSnapshot? startRadio,
    required LocationStatus? startLocation,
    required bool ratChanged,
  }) async {
    String? sessionId;
    String? measurementId;
    final recording = ref.read(recordingControllerProvider);
    final samples = ref.read(sampleRepositoryProvider);
    final activeId = recording.sessionId;
    if (recording.isActive && activeId != null) {
      sessionId = activeId;
      measurementId = await samples.latestMeasurementId(activeId);
    } else if (startRadio != null) {
      final info = await ref.read(deviceInfoSourceProvider).getDeviceInfo();
      final deviceId = await ref
          .read(deviceRegistryProvider)
          .ensureDevice(info);
      final sessions = ref.read(sessionRepositoryProvider);
      final session = await sessions.createSession(
        deviceId: deviceId,
        name: RecordingController.defaultName(startedAt.toLocal())
            .replaceFirst('Session', 'Speed test'),
        type: SessionType.singleTest,
        samplingIntervalMs: 1000,
      );
      await sessions.startRecording(session.id);
      measurementId = await samples.recordSample(
        sessionId: session.id,
        radio: startRadio,
        location: startLocation,
      );
      await sessions.finishRecording(session.id);
      sessionId = session.id;
    }
    await ref
        .read(speedTestStoreProvider)
        .saveSpeedTest(
          SpeedTestRecord(
            id: uuid7(),
            timestamp: startedAt,
            methodologyVersion: methodologyVersion,
            serverId: url,
            result: result,
            sessionId: sessionId,
            measurementId: measurementId,
            ratChanged: ratChanged,
          ),
        );
  }
}

final speedTestControllerProvider =
    NotifierProvider<SpeedTestController, SpeedTestState>(
      SpeedTestController.new,
    );

/// Keeps radio and GNSS subscribed while a test runs, independent of the
/// screen, so the start snapshot and RAT changes are captured.
final speedTestPipelineProvider = Provider<void>((ref) {
  final running = ref.watch(
    speedTestControllerProvider.select((s) => s.running),
  );
  if (!running) return;
  ref
    ..listen(radioSnapshotProvider, (previous, next) {})
    ..listen(locationStatusProvider, (previous, next) {});
});
