import 'dart:async';

import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/latency_test_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/latency_test_repository.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

class PlatformLatencyEngine implements LatencyEngine {
  const PlatformLatencyEngine({
    EventChannel channel = MeasurementChannels.latency,
  }) : this._(channel);

  const PlatformLatencyEngine._(this._channel);

  final EventChannel _channel;

  @override
  Stream<LatencyEvent> run(LatencyConfig config) => _channel
      .receiveBroadcastStream(<String, Object?>{
        'host': config.host,
        'port': config.port,
        'protocols': [for (final p in config.protocols) p.wireValue],
        'probes': config.probes,
        'interval_ms': config.interval.inMilliseconds,
        'timeout_ms': config.timeout.inMilliseconds,
      })
      .map(LatencyTestMapper.fromChannel)
      .transform(
        StreamTransformer<LatencyEvent, LatencyEvent>.fromHandlers(
          handleError:
              (
                Object error,
                StackTrace stackTrace,
                EventSink<LatencyEvent> sink,
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
