import 'dart:async';

import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/speed_test_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/speed_test_repository.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

class PlatformSpeedTestEngine implements SpeedTestEngine {
  const PlatformSpeedTestEngine({
    EventChannel channel = MeasurementChannels.speed,
  }) : this._(channel);

  const PlatformSpeedTestEngine._(this._channel);

  final EventChannel _channel;

  @override
  Stream<SpeedTestEvent> run(SpeedTestConfig config) => _channel
      .receiveBroadcastStream(<String, Object?>{
        'server_url': config.serverUrl,
        'streams': config.streams,
        'direction_ms': config.directionDuration.inMilliseconds,
      })
      .map(SpeedTestMapper.fromChannel)
      .transform(
        StreamTransformer<SpeedTestEvent, SpeedTestEvent>.fromHandlers(
          handleError:
              (
                Object error,
                StackTrace stackTrace,
                EventSink<SpeedTestEvent> sink,
              ) {
                sink.addError(
                  error is PlatformException
                      ? MeasurementException(
                          error.code,
                          error.message ?? error.code,
                        )
                      : error,
                  stackTrace,
                );
              },
        ),
      );
}
