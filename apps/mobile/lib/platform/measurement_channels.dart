import 'package:flutter/services.dart';

/// Platform channels to the Kotlin measurement layer.
/// Contract: docs/features/signal-monitor/API.md (ADR-013).
abstract final class MeasurementChannels {
  static const String controlName = 'org.opennetiq/measurement';
  static const String radioName = 'org.opennetiq/radio';

  static const MethodChannel control = MethodChannel(controlName);
  static const EventChannel radio = EventChannel(radioName);

  static const String getPermissionStatus = 'getPermissionStatus';
  static const String requestPermissions = 'requestPermissions';
}
