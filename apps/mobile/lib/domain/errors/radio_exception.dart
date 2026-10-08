import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';

/// Error reported by the radio measurement layer.
class RadioException extends MeasurementException {
  const RadioException(super.code, super.message);

  static const String permissionDenied = MeasurementException.permissionDenied;
  static const String noTelephony = 'NO_TELEPHONY';

  @override
  String toString() => 'RadioException($code): $message';
}
