import 'dart:async';

import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/repositories/recording_service.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';

/// Records calls to the native foreground service.
class FakeRecordingService implements RecordingService {
  FakeRecordingService({
    this.startError,
    this.ignoringBatteryOptimizations = true,
  });

  final Object? startError;
  bool? ignoringBatteryOptimizations;
  final calls = <String>[];
  final updates = <String>[];
  String? lastTitle;
  int batterySettingsOpened = 0;
  final _events = StreamController<RecordingServiceEvent>.broadcast();

  bool get hasListener => _events.hasListener;

  void emit(RecordingServiceEvent event) => _events.add(event);

  @override
  Stream<RecordingServiceEvent> get events => _events.stream;

  @override
  Future<void> start({required String title, required String text}) async {
    calls.add('start');
    lastTitle = title;
    final e = startError;
    if (e != null) throw e;
  }

  @override
  Future<void> update({required String title, required String text}) async {
    calls.add('update');
    updates.add(text);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    final value = ignoringBatteryOptimizations;
    if (value == null) throw StateError('unavailable');
    return value;
  }

  @override
  Future<bool> openBatterySettings() async {
    batterySettingsOpened++;
    return true;
  }
}

/// Controllable clock for duration and completeness assertions.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 10, 8, 1);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

/// Controller with a fixed initial state that records UI commands.
class StubRecordingController extends RecordingController {
  StubRecordingController([this.initial = const RecordingState()]);

  final RecordingState initial;
  RecordingOptions? started;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;

  @override
  RecordingState build() => initial;

  @override
  Future<void> start([
    RecordingOptions options = const RecordingOptions(),
  ]) async {
    started = options;
  }

  @override
  Future<void> pause() async {
    pauses++;
    state = state.copyWith(phase: RecordingPhase.paused, activeSince: null);
  }

  @override
  Future<void> resume() async {
    resumes++;
    state = state.copyWith(phase: RecordingPhase.recording);
  }

  @override
  Future<void> stop() async {
    stops++;
    state = const RecordingState();
  }

  @override
  void onSnapshot(RadioSnapshot radio, LocationStatus? location) {}
}
