/// Permission and capability state for radio monitoring.
class RadioPermissions {
  const RadioPermissions({
    required this.location,
    required this.phoneState,
    required this.hasTelephony,
    this.apiLevel,
    this.consent = true,
  });

  /// Precise location: required by Android to read cell information.
  final bool location;

  /// Phone state: required for network type and 5G NSA detection.
  final bool phoneState;

  final bool hasTelephony;
  final int? apiLevel;

  /// The user consented to radio and location measurement (ADR-018).
  /// Android permissions alone are not enough.
  final bool consent;

  bool get canMonitor => consent && hasTelephony && location;

  /// GNSS collection allowed.
  bool get canLocate => consent && location;

  RadioPermissions withConsent(bool consent) => RadioPermissions(
    location: location,
    phoneState: phoneState,
    hasTelephony: hasTelephony,
    apiLevel: apiLevel,
    consent: consent,
  );

  /// 5G NSA detection needs phone state and Android 11 (API 30) or newer.
  bool get canDetectNsa => phoneState && (apiLevel ?? 0) >= 30;
}
