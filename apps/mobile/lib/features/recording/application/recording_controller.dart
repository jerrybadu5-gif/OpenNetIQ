import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/repositories/recording_service.dart';
import 'package:opennetiq_mobile/domain/services/sample_gaps.dart';
import 'package:opennetiq_mobile/domain/services/track_segments.dart';
import 'package:opennetiq_mobile/features/recording/application/live_track.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

enum RecordingPhase { idle, starting, recording, paused, stopping }

/// User choices for a new session.
class RecordingOptions {
  const RecordingOptions({
    this.type = SessionType.drive,
    this.interval = defaultInterval,
    this.name,
    this.operatorUnderTest,
  });

  /// Sampling intervals allowed by the methodology (schema CHECK).
  static const List<Duration> allowedIntervals = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];
  static const Duration defaultInterval = Duration(seconds: 1);

  final SessionType type;
  final Duration interval;

  /// Session name; a dated default is used when null or blank.
  final String? name;
  final String? operatorUnderTest;
}

class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.options = const RecordingOptions(),
    this.sessionId,
    this.sessionName,
    this.lastSessionId,
    this.lastReport,
    this.recordedSamples = 0,
    this.failedSamples = 0,
    this.activeBefore = Duration.zero,
    this.activeSince,
    this.pauses = const [],
    this.backgroundAvailable = true,
    this.error,
  });

  final RecordingPhase phase;
  final RecordingOptions options;

  /// Session being recorded (null when idle).
  final String? sessionId;
  final String? sessionName;

  /// Most recently finished session and its gap analysis.
  final String? lastSessionId;
  final GapReport? lastReport;

  /// Ticks stored / not stored in this session (never silent).
  final int recordedSamples;
  final int failedSamples;

  /// Active (unpaused) time before [activeSince].
  final Duration activeBefore;

  /// Start of the current active stretch; null while paused or idle.
  final DateTime? activeSince;
  final List<PauseWindow> pauses;

  /// False when the foreground service could not start: recording then
  /// continues only while the app is open.
  final bool backgroundAvailable;
  final String? error;

  bool get isRecording => phase == RecordingPhase.recording;
  bool get isPaused => phase == RecordingPhase.paused;

  /// A session is open (recording or paused).
  bool get isActive => isRecording || isPaused;

  Duration get interval => options.interval;

  /// Recording time excluding pauses.
  Duration activeDuration(DateTime now) {
    final since = activeSince;
    return since == null ? activeBefore : activeBefore + now.difference(since);
  }

  double? liveCompleteness(DateTime now) => SampleGaps.liveCompleteness(
    recordedSamples,
    activeDuration(now),
    interval,
  );

  static const Object _keep = Object();

  RecordingState copyWith({
    RecordingPhase? phase,
    int? recordedSamples,
    int? failedSamples,
    Duration? activeBefore,
    Object? activeSince = _keep,
    List<PauseWindow>? pauses,
    bool? backgroundAvailable,
    Object? error = _keep,
  }) => RecordingState(
    phase: phase ?? this.phase,
    options: options,
    sessionId: sessionId,
    sessionName: sessionName,
    lastSessionId: lastSessionId,
    lastReport: lastReport,
    recordedSamples: recordedSamples ?? this.recordedSamples,
    failedSamples: failedSamples ?? this.failedSamples,
    activeBefore: activeBefore ?? this.activeBefore,
    activeSince: identical(activeSince, _keep)
        ? this.activeSince
        : activeSince as DateTime?,
    pauses: pauses ?? this.pauses,
    backgroundAvailable: backgroundAvailable ?? this.backgroundAvailable,
    error: identical(error, _keep) ? this.error : error as String?,
  );
}

/// Session engine (issues #16, #17): lifecycle created -> recording <->
/// paused -> completed | aborted, crash-safe per-sample commits, foreground
/// service for screen-off recording and gap detection.
class RecordingController extends Notifier<RecordingState> {
  Future<void> _writes = Future<void>.value();
  StreamSubscription<RecordingServiceEvent>? _serviceEvents;
  DateTime? _lastNotificationAt;

  /// Minimum spacing of notification updates (battery, rate limits).
  static const Duration notificationPeriod = Duration(seconds: 5);

  @override
  RecordingState build() {
    ref.onDispose(() => _serviceEvents?.cancel());
    return const RecordingState();
  }

  DateTime _now() => ref.read(clockProvider)();

  RecordingService get _service => ref.read(recordingServiceProvider);

  /// Default session name, local time, e.g. `Session 2026-10-08 14:36`.
  static String defaultName(DateTime local) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Session ${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> start([
    RecordingOptions options = const RecordingOptions(),
  ]) async {
    if (state.phase != RecordingPhase.idle) return;
    if (!RecordingOptions.allowedIntervals.contains(options.interval)) {
      state = RecordingState(
        lastSessionId: state.lastSessionId,
        lastReport: state.lastReport,
        error: 'Unsupported sampling interval ${options.interval.inSeconds} s',
      );
      return;
    }
    final lastSessionId = state.lastSessionId;
    final lastReport = state.lastReport;
    state = RecordingState(
      phase: RecordingPhase.starting,
      options: options,
      lastSessionId: lastSessionId,
      lastReport: lastReport,
    );
    final name = options.name?.trim();
    final sessionName = name == null || name.isEmpty
        ? defaultName(_now().toLocal())
        : name;
    final String sessionId;
    try {
      await ref.read(startupRecoveryProvider.future);
      final info = await ref.read(deviceInfoSourceProvider).getDeviceInfo();
      final deviceId = await ref
          .read(deviceRegistryProvider)
          .ensureDevice(info);
      final sessions = ref.read(sessionRepositoryProvider);
      final operatorName = options.operatorUnderTest?.trim();
      final session = await sessions.createSession(
        deviceId: deviceId,
        name: sessionName,
        type: options.type,
        samplingIntervalMs: options.interval.inMilliseconds,
        operatorUnderTest: operatorName == null || operatorName.isEmpty
            ? null
            : operatorName,
      );
      sessionId = session.id;
      await sessions.startRecording(sessionId);
    } on Object catch (e) {
      state = RecordingState(
        lastSessionId: lastSessionId,
        lastReport: lastReport,
        error: 'Could not start recording: $e',
      );
      return;
    }
    ref.read(liveTrackProvider.notifier).reset();
    state = RecordingState(
      phase: RecordingPhase.recording,
      options: options,
      sessionId: sessionId,
      sessionName: sessionName,
      lastSessionId: lastSessionId,
      lastReport: lastReport,
      activeSince: _now(),
    );
    await _startService();
  }

  Future<void> _startService() async {
    final service = _service;
    _serviceEvents ??= service.events.listen(_onServiceEvent);
    try {
      await service.start(title: _title(), text: 'Starting...');
      _lastNotificationAt = _now();
    } on Object catch (e) {
      state = state.copyWith(
        backgroundAvailable: false,
        error:
            'Background recording unavailable ($e). Keep OpenNetIQ open '
            'and the screen on.',
      );
    }
  }

  void _onServiceEvent(RecordingServiceEvent event) {
    switch (event) {
      case RecordingStopRequested():
        unawaited(stop());
      case RecordingServiceFailed(:final message):
        state = state.copyWith(
          backgroundAvailable: false,
          error: 'Background recording stopped: $message',
        );
    }
  }

  /// Stores one tick. Writes are queued so samples keep their order; each
  /// sample is its own transaction (crash-safe).
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
        state = state.copyWith(recordedSamples: state.recordedSamples + 1);
        ref
            .read(liveTrackProvider.notifier)
            .add(TrackSegments.fromTick(radio, location));
        _maybeUpdateNotification(radio, location);
      } on Object catch (e) {
        state = state.copyWith(
          failedSamples: state.failedSamples + 1,
          error: 'Sample not stored: $e',
        );
      }
    });
  }

  Future<void> pause() async {
    final sessionId = state.sessionId;
    if (!state.isRecording || sessionId == null) return;
    final now = _now();
    state = state.copyWith(
      phase: RecordingPhase.paused,
      activeBefore: state.activeDuration(now),
      activeSince: null,
      pauses: [...state.pauses, PauseWindow(now)],
    );
    await _persist(
      () => ref.read(sessionRepositoryProvider).pauseRecording(sessionId),
    );
    _notify(text: 'Paused - ${state.recordedSamples} samples');
  }

  Future<void> resume() async {
    final sessionId = state.sessionId;
    if (!state.isPaused || sessionId == null) return;
    final now = _now();
    state = state.copyWith(
      phase: RecordingPhase.recording,
      activeSince: now,
      pauses: [for (final p in state.pauses) p.close(now)],
    );
    await _persist(
      () => ref.read(sessionRepositoryProvider).startRecording(sessionId),
    );
    _notify(text: 'Recording - ${state.recordedSamples} samples');
  }

  Future<void> stop() async {
    final sessionId = state.sessionId;
    if (!state.isActive || sessionId == null) return;
    final now = _now();
    final pauses = [for (final p in state.pauses) p.close(now)];
    state = state.copyWith(
      phase: RecordingPhase.stopping,
      activeBefore: state.activeDuration(now),
      activeSince: null,
      pauses: pauses,
    );
    await _writes;
    String? error = state.error;
    GapReport? report;
    try {
      await ref.read(sessionRepositoryProvider).finishRecording(sessionId);
      final timestamps = await ref
          .read(sampleRepositoryProvider)
          .sampleTimestamps(sessionId);
      report = SampleGaps.analyse(timestamps, state.interval, pauses: pauses);
    } on Object catch (e) {
      error = 'Could not close session: $e';
    }
    await _serviceEvents?.cancel();
    _serviceEvents = null;
    try {
      await _service.stop();
    } on Object {
      // Already stopped or unavailable.
    }
    state = RecordingState(
      options: state.options,
      lastSessionId: sessionId,
      lastReport: report,
      recordedSamples: state.recordedSamples,
      failedSamples: state.failedSamples,
      activeBefore: state.activeBefore,
      error: error,
    );
  }

  Future<void> _persist(Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (e) {
      state = state.copyWith(error: 'Session status not saved: $e');
    }
  }

  String _title() => 'Recording ${state.sessionName ?? 'session'}';

  void _maybeUpdateNotification(RadioSnapshot radio, LocationStatus? location) {
    final now = _now();
    final last = _lastNotificationAt;
    if (last != null && now.difference(last) < notificationPeriod) return;
    _notify(text: notificationText(state.recordedSamples, radio, location));
  }

  void _notify({required String text}) {
    if (!state.backgroundAvailable) return;
    _lastNotificationAt = _now();
    unawaited(
      _service.update(title: _title(), text: text).catchError((Object _) {}),
    );
  }

  /// e.g. `120 samples - 4G LTE RSRP -95 dBm - GPS Good`.
  static String notificationText(
    int samples,
    RadioSnapshot radio,
    LocationStatus? location,
  ) {
    final parts = <String>['$samples samples', radio.networkType.label];
    final cell = radio.primaryCell;
    final level = cell?.levelDbm;
    if (cell != null && level != null) {
      parts.add('${cell.levelLabel} ${level.round()} dBm');
    }
    parts.add('GPS ${location?.quality.label ?? 'n/a'}');
    return parts.join(' - ');
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
