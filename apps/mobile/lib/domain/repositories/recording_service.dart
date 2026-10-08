/// Native drive-test foreground service (issue #17, ADR-014): keeps
/// sampling alive with the screen off or the task swiped away.
abstract interface class RecordingService {
  /// Starts the foreground service with its ongoing notification.
  Future<void> start({required String title, required String text});

  /// Updates the notification text; no-op when the service is not running.
  Future<void> update({required String title, required String text});

  Future<void> stop();

  /// Whether Android battery optimisation is disabled for the app.
  Future<bool> isIgnoringBatteryOptimizations();

  /// Opens the system battery-optimisation settings. False if unavailable.
  Future<bool> openBatterySettings();

  /// Events raised by the service (notification Stop action, failures).
  Stream<RecordingServiceEvent> get events;
}

sealed class RecordingServiceEvent {
  const RecordingServiceEvent();
}

/// The user tapped "Stop" in the recording notification.
final class RecordingStopRequested extends RecordingServiceEvent {
  const RecordingStopRequested();
}

/// The service could not run in the foreground (e.g. permission revoked).
final class RecordingServiceFailed extends RecordingServiceEvent {
  const RecordingServiceFailed(this.code, this.message);

  final String code;
  final String message;
}
