import 'dart:async';

import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/repositories/session_repository.dart';

MeasurementSession session({
  String id = 's1',
  String name = 'Session 2026-10-08 09:05',
  SessionStatus status = SessionStatus.completed,
  int sampleCount = 120,
  double? distanceM = 2350,
}) => MeasurementSession(
  id: id,
  deviceId: 'd1',
  name: name,
  type: SessionType.drive,
  status: status,
  samplingIntervalMs: 1000,
  methodologyVersion: '1.0.0',
  sampleCount: sampleCount,
  createdAt: DateTime.utc(2026, 10, 8),
  updatedAt: DateTime.utc(2026, 10, 8),
  startedAt: DateTime.utc(2026, 10, 8, 0, 0),
  endedAt: status == SessionStatus.recording
      ? null
      : DateTime.utc(2026, 10, 8, 0, 2, 5),
  distanceM: distanceM,
);

/// In-memory SessionRepository for widget tests.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository(List<MeasurementSession> initial)
    : _sessions = [...initial];

  final List<MeasurementSession> _sessions;
  final _changes = StreamController<List<MeasurementSession>>.broadcast();
  final deleted = <String>[];

  void _emit() => _changes.add(List.unmodifiable(_sessions));

  @override
  Stream<List<MeasurementSession>> watchSessions() async* {
    yield List.unmodifiable(_sessions);
    yield* _changes.stream;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleted.add(sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);
    _emit();
  }

  @override
  Future<void> deleteAllSessions() async {
    deleted.addAll(_sessions.map((s) => s.id));
    _sessions.clear();
    _emit();
  }

  @override
  Future<MeasurementSession> createSession({
    required String deviceId,
    required String name,
    required SessionType type,
    required int samplingIntervalMs,
    String? operatorUnderTest,
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<void> startRecording(String sessionId) => throw UnimplementedError();

  @override
  Future<void> finishRecording(String sessionId, {bool aborted = false}) =>
      throw UnimplementedError();

  @override
  Future<MeasurementSession?> getSession(String sessionId) async =>
      _sessions.where((s) => s.id == sessionId).firstOrNull;

  @override
  Stream<MeasurementSession?> watchSession(String sessionId) =>
      Stream.value(_sessions.where((s) => s.id == sessionId).firstOrNull);
}
