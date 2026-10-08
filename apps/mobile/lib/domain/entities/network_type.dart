/// Radio generation used for grouping and display.
enum RadioGeneration {
  g2('2G'),
  g3('3G'),
  g4('4G'),
  g5('5G'),
  unknown('Unknown'),
  none('No service');

  const RadioGeneration(this.label);

  final String label;
}

/// Network type of the serving connection (`samples.network_type` in
/// docs/standards/DATA-DICTIONARY.md). Pure domain type: no Flutter imports.
enum NetworkType {
  gsm('GSM', 'GSM', RadioGeneration.g2),
  gprs('GPRS', 'GPRS', RadioGeneration.g2),
  edge('EDGE', 'EDGE', RadioGeneration.g2),
  umts('UMTS', 'UMTS', RadioGeneration.g3),
  hspa('HSPA', 'HSPA', RadioGeneration.g3),
  hspap('HSPAP', 'HSPA+', RadioGeneration.g3),
  lte('LTE', 'LTE', RadioGeneration.g4),
  lteCa('LTE_CA', 'LTE-A', RadioGeneration.g4),
  nrNsa('NR_NSA', '5G NSA', RadioGeneration.g5),
  nrNsaMmwave('NR_NSA_MMWAVE', '5G NSA mmWave', RadioGeneration.g5),
  nrSa('NR_SA', '5G SA', RadioGeneration.g5),
  unknown('UNKNOWN', 'Unknown', RadioGeneration.unknown),
  none('NONE', 'No service', RadioGeneration.none);

  const NetworkType(this.wireValue, this.label, this.generation);

  /// Stable value used in the DB, API and platform channel.
  final String wireValue;

  /// Human-readable label for the UI.
  final String label;

  final RadioGeneration generation;

  /// 5G non-standalone: LTE anchor plus NR secondary leg.
  bool get isNsa => this == nrNsa || this == nrNsaMmwave;

  static NetworkType? fromWire(String? value) {
    for (final t in values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }
}
