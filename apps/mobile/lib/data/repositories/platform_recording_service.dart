import 'dart:async';

import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/channel_reader.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/recording_service.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

/// [RecordingService] over the control channel. Also handles native -> Dart
/// calls (`onStopRequested`, `onServiceError`) on the same channel.
class PlatformRecordingService implements RecordingService {
  PlatformRecordingService({
    MethodChannel channel = MeasurementChannels.control,
  }) : this._(channel);

  PlatformRecordingService._(this._channel) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<RecordingServiceEvent> _events =
      StreamController<RecordingServiceEvent>.broadcast();

  @override
  Stream<RecordingServiceEvent> get events => _events.stream;

  @override
  Future<void> start({required String title, required String text}) => _invoke(
    MeasurementChannels.startRecordingService,
    {'title': title, 'text': text},
  );

  @override
  Future<void> update({required String title, required String text}) => _invoke(
    MeasurementChannels.updateRecordingService,
    {'title': title, 'text': text},
  );

  @override
  Future<void> stop() => _invoke(MeasurementChannels.stopRecordingService);

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        MeasurementChannels.getBatteryOptimization,
      );
      return ChannelReader(result, 'battery').requireBool('ignoring');
    } on PlatformException catch (e) {
      throw MeasurementException(e.code, e.message ?? e.code);
    }
  }

  @override
  Future<bool> openBatterySettings() async {
    try {
      return await _channel.invokeMethod<bool>(
            MeasurementChannels.openBatterySettings,
          ) ??
          false;
    } on PlatformException catch (e) {
      throw MeasurementException(e.code, e.message ?? e.code);
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_events.close());
  }

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      throw MeasurementException(e.code, e.message ?? e.code);
    }
  }

  /// Returns true when a recording session took the stop request; false
  /// tells the native service to stop itself.
  Future<Object?> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case MeasurementChannels.onStopRequested:
        if (!_events.hasListener) return false;
        _events.add(const RecordingStopRequested());
        return true;
      case MeasurementChannels.onServiceError:
        final args = call.arguments;
        final reader = args is Map<Object?, Object?>
            ? ChannelReader(args, 'service_error')
            : null;
        _events.add(
          RecordingServiceFailed(
            reader?.string('code') ?? 'UNKNOWN',
            reader?.string('message') ?? 'Recording service error',
          ),
        );
        return null;
      default:
        throw MissingPluginException('No handler for ${call.method}');
    }
  }
}
