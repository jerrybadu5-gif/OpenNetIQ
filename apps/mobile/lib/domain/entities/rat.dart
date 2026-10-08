/// Radio access technology of a single cell (`cell_observations.rat`).
enum Rat {
  gsm('GSM'),
  wcdma('WCDMA'),
  lte('LTE'),
  nr('NR'),
  cdma('CDMA'),
  tdscdma('TDSCDMA');

  const Rat(this.wireValue);

  final String wireValue;

  static Rat? fromWire(String? value) {
    for (final r in values) {
      if (r.wireValue == value) return r;
    }
    return null;
  }
}
