/// Permission and capability state for radio monitoring.
class RadioPermissions {
  const RadioPermissions({
    required this.location,
    required this.phoneState,
    required this.hasTelephony,
    this.apiLevel,
  });

  /// Precise location: required by Android to read cell information.
  final bool location;

  /// Phone state: required for network type and 5G NSA detection.
  final bool phoneState;

  final bool hasTelephony;
  final int? apiLevel;

  bool get canMonitor => hasTelephony && location;

  /// 5G NSA detection needs phone state and Android 11 (API 30) or newer.
  bool get canDetectNsa => phoneState && (apiLevel ?? 0) >= 30;
}
