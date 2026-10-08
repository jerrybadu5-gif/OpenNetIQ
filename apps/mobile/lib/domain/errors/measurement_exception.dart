/// Error reported by a native measurement collector.
class MeasurementException implements Exception {
  const MeasurementException(this.code, this.message);

  static const String permissionDenied = 'PERMISSION_DENIED';

  final String code;
  final String message;

  @override
  String toString() => 'MeasurementException($code): $message';
}

/// GNSS collector errors (issue #14).
class LocationException extends MeasurementException {
  const LocationException(super.code, super.message);

  static const String noGnss = 'NO_GNSS';

  @override
  String toString() => 'LocationException($code): $message';
}
