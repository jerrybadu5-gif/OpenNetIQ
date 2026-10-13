/// Consent ledger (`consent_log`, ADR-018). Append-only: the latest row per
/// scope and policy version is the current decision.
library;

enum ConsentScope {
  location('location'),
  radio('radio'),
  backgroundLocation('background_location'),
  upload('upload');

  const ConsentScope(this.wireValue);

  final String wireValue;

  static ConsentScope? fromWire(String? value) {
    for (final s in values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }

  /// Scopes covered by the "measure radio and location" decision.
  static const Set<ConsentScope> measurement = {location, radio};
}

class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.scope,
    required this.granted,
    required this.policyVersion,
    required this.timestamp,
  });

  final String id;
  final ConsentScope scope;
  final bool granted;
  final String policyVersion;

  /// UTC.
  final DateTime timestamp;
}

/// Current decisions for one policy version.
class ConsentStatus {
  const ConsentStatus({required this.policyVersion, this.decisions = const {}});

  /// Latest decision per scope from [ledger] for [policyVersion].
  factory ConsentStatus.fromLedger(
    String policyVersion,
    Iterable<ConsentRecord> ledger,
  ) {
    final latest = <ConsentScope, ConsentRecord>{};
    for (final r in ledger) {
      if (r.policyVersion != policyVersion) continue;
      final seen = latest[r.scope];
      if (seen == null || !r.timestamp.isBefore(seen.timestamp)) {
        latest[r.scope] = r;
      }
    }
    return ConsentStatus(
      policyVersion: policyVersion,
      decisions: {for (final e in latest.entries) e.key: e.value.granted},
    );
  }

  final String policyVersion;
  final Map<ConsentScope, bool> decisions;

  /// The user answered the onboarding question for this policy version.
  bool get decided =>
      ConsentScope.measurement.every((s) => decisions.containsKey(s));

  /// Radio and location measurement allowed.
  bool get measurement =>
      ConsentScope.measurement.every((s) => decisions[s] ?? false);
}
