/// Radio access technology. Pure domain type: no Flutter or plugin imports.
enum NetworkType {
  gsm('GSM'),
  wcdma('WCDMA'),
  lte('LTE'),
  nrNsa('NR_NSA'),
  nrSa('NR_SA');

  const NetworkType(this.wireValue);

  /// Stable value used in the DB and API.
  final String wireValue;

  static NetworkType? fromWire(String? value) {
    for (final t in values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }
}
