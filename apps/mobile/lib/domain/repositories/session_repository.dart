import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';

abstract interface class SessionRepository {
  Future<MeasurementSession> createSession({
    required String deviceId,
    required String name,
    required SessionType type,
    required int samplingIntervalMs,
    String? operatorUnderTest,
    String? notes,
  });

  /// Sets status `recording` and `started_at` (first start only).
  Future<void> startRecording(String sessionId);

  /// Sets status `paused` (resume with [startRecording]).
  Future<void> pauseRecording(String sessionId);

  /// Sets status `completed` (or `aborted`) and `ended_at`.
  Future<void> finishRecording(String sessionId, {bool aborted = false});

  Future<MeasurementSession?> getSession(String sessionId);

  /// Crash recovery at app start: sessions left `created`, `recording` or
  /// `paused` by a killed process become `aborted`, ending at their last
  /// sample. Returns the number of sessions aborted.
  Future<int> abortOrphanedSessions();

  /// Newest first.
  Stream<List<MeasurementSession>> watchSessions();

  Stream<MeasurementSession?> watchSession(String sessionId);

  /// Deletes the session with all its samples and cells (privacy control).
  Future<void> deleteSession(String sessionId);

  Future<void> deleteAllSessions();
}

abstract interface class SampleRepository {
  /// Stores one tick: sample row + all cell observations, updates the
  /// session's sample count and distance atomically. Returns measurement_id.
  Future<String> recordSample({
    required String sessionId,
    required RadioSnapshot radio,
    LocationStatus? location,
  });

  Future<int> countSamples(String sessionId);

  /// Sample timestamps of a session, oldest first (gap detection).
  Future<List<DateTime>> sampleTimestamps(String sessionId);

  /// Samples reduced to position + primary serving-cell level, oldest first
  /// (session map and statistics).
  Future<List<SamplePoint>> loadSamplePoints(String sessionId);
}
