import 'package:flutter/services.dart';

/// Platform channels to the Kotlin measurement layer.
/// Contracts: docs/features/signal-monitor/API.md and
/// docs/features/location/API.md and docs/features/drive-test/API.md
/// (ADR-013, ADR-014).
abstract final class MeasurementChannels {
  static const String controlName = 'org.opennetiq/measurement';
  static const String radioName = 'org.opennetiq/radio';
  static const String locationName = 'org.opennetiq/location';
  static const String speedName = 'org.opennetiq/speed';

  static const MethodChannel control = MethodChannel(controlName);
  static const EventChannel radio = EventChannel(radioName);
  static const EventChannel location = EventChannel(locationName);
  static const EventChannel speed = EventChannel(speedName);

  static const String getPermissionStatus = 'getPermissionStatus';
  static const String requestPermissions = 'requestPermissions';
  static const String getDeviceInfo = 'getDeviceInfo';
  static const String startRecordingService = 'startRecordingService';
  static const String updateRecordingService = 'updateRecordingService';
  static const String stopRecordingService = 'stopRecordingService';
  static const String getBatteryOptimization = 'getBatteryOptimization';
  static const String openBatterySettings = 'openBatterySettings';

  // Native -> Dart calls on the control channel.
  static const String onStopRequested = 'onStopRequested';
  static const String onServiceError = 'onServiceError';
}
