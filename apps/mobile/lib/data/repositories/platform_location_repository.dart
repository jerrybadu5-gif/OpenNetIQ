import 'dart:async';

import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/location_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/location_repository.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

class PlatformLocationRepository implements LocationRepository {
  const PlatformLocationRepository({
    EventChannel channel = MeasurementChannels.location,
  }) : this._(channel);

  const PlatformLocationRepository._(this._channel);

  final EventChannel _channel;

  @override
  Stream<LocationStatus> watchLocation({
    Duration interval = const Duration(seconds: 1),
  }) {
    return _channel
        .receiveBroadcastStream(<String, Object?>{
          'interval_ms': interval.inMilliseconds,
        })
        .map(LocationMapper.fromChannel)
        .transform(
          StreamTransformer<LocationStatus, LocationStatus>.fromHandlers(
            handleError:
                (
                  Object error,
                  StackTrace stackTrace,
                  EventSink<LocationStatus> sink,
                ) {
                  sink.addError(
                    error is PlatformException
                        ? LocationException(
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
}
