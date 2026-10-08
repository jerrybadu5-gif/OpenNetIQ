import 'dart:async';

import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/radio_snapshot_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/errors/radio_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/radio_repository.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

class PlatformRadioRepository implements RadioRepository {
  const PlatformRadioRepository({
    MethodChannel control = MeasurementChannels.control,
    EventChannel radio = MeasurementChannels.radio,
  }) : this._(control, radio);

  const PlatformRadioRepository._(this._control, this._radio);

  final MethodChannel _control;
  final EventChannel _radio;

  @override
  Stream<RadioSnapshot> watchSnapshots({
    Duration interval = const Duration(seconds: 1),
  }) {
    return _radio
        .receiveBroadcastStream(<String, Object?>{
          'interval_ms': interval.inMilliseconds,
        })
        .map(RadioSnapshotMapper.fromChannel)
        .transform(
          StreamTransformer<RadioSnapshot, RadioSnapshot>.fromHandlers(
            handleError:
                (
                  Object error,
                  StackTrace stackTrace,
                  EventSink<RadioSnapshot> sink,
                ) {
                  sink.addError(_translate(error), stackTrace);
                },
          ),
        );
  }

  @override
  Future<RadioPermissions> getPermissions() =>
      _invokePermissions(MeasurementChannels.getPermissionStatus);

  @override
  Future<RadioPermissions> requestPermissions() =>
      _invokePermissions(MeasurementChannels.requestPermissions);

  Future<RadioPermissions> _invokePermissions(String method) async {
    try {
      final result = await _control.invokeMapMethod<String, Object?>(method);
      return RadioSnapshotMapper.permissionsFromChannel(result);
    } on PlatformException catch (e) {
      throw _translate(e);
    }
  }

  static Object _translate(Object error) => error is PlatformException
      ? RadioException(error.code, error.message ?? error.code)
      : error;
}
