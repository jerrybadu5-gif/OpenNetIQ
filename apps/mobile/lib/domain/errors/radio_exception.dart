/// Error reported by the radio measurement layer.
class RadioException implements Exception {
  const RadioException(this.code, this.message);

  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String noTelephony = 'NO_TELEPHONY';

  final String code;
  final String message;

  @override
  String toString() => 'RadioException($code): $message';
}
