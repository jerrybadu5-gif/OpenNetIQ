import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// Display classes for signal levels (MEASUREMENT-METHODOLOGY.md section 4).
/// UI classes only, not regulatory coverage thresholds.
enum SignalQuality {
  excellent('Excellent'),
  good('Good'),
  fair('Fair'),
  poor('Poor'),
  noService('No service');

  const SignalQuality(this.label);

  final String label;

  /// Classifies the RAT's main level metric (see CellObservation.levelDbm).
  static SignalQuality fromLevel(Rat rat, double dbm) {
    final t = switch (rat) {
      Rat.wcdma => const [-75.0, -85.0, -95.0, -105.0],
      Rat.gsm => const [-70.0, -80.0, -90.0, -100.0],
      _ => const [-80.0, -90.0, -100.0, -110.0],
    };
    if (dbm >= t[0]) return excellent;
    if (dbm >= t[1]) return good;
    if (dbm >= t[2]) return fair;
    if (dbm >= t[3]) return poor;
    return noService;
  }

  /// LTE RS-SNR / NR SS-SINR in dB.
  static SignalQuality fromSinr(double db) {
    if (db >= 20) return excellent;
    if (db >= 13) return good;
    if (db >= 0) return fair;
    return poor;
  }
}
