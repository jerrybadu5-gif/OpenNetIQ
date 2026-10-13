import 'package:opennetiq_mobile/domain/entities/consent.dart';

abstract interface class ConsentRepository {
  /// Appends one row per scope (same timestamp), atomically.
  Future<void> record(
    Set<ConsentScope> scopes, {
    required bool granted,
    required String policyVersion,
  });

  /// Whole ledger, newest first.
  Future<List<ConsentRecord>> ledger();
}

/// Removes measurement data (sessions, samples, cells, tests). The consent
/// ledger, device row and settings are kept.
abstract interface class MeasurementDataEraser {
  Future<void> eraseMeasurements();
}
