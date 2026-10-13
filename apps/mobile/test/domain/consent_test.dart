import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';

ConsentRecord rec(
  ConsentScope s,
  bool granted,
  int minute, {
  String v = '1.0',
}) => ConsentRecord(
  id: '$s$minute',
  scope: s,
  granted: granted,
  policyVersion: v,
  timestamp: DateTime.utc(2026, 10, 13, 1, minute),
);

void main() {
  test('empty ledger: undecided, no measurement', () {
    final s = ConsentStatus.fromLedger('1.0', const []);
    expect(s.decided, isFalse);
    expect(s.measurement, isFalse);
  });

  test('latest decision per scope wins', () {
    final s = ConsentStatus.fromLedger('1.0', [
      rec(ConsentScope.location, true, 1),
      rec(ConsentScope.radio, true, 1),
      rec(ConsentScope.location, false, 5),
      rec(ConsentScope.radio, false, 5),
    ]);
    expect(s.decided, isTrue);
    expect(s.measurement, isFalse);
  });

  test('decisions for an older policy do not count', () {
    final s = ConsentStatus.fromLedger('2.0', [
      rec(ConsentScope.location, true, 1),
      rec(ConsentScope.radio, true, 1),
    ]);
    expect(s.decided, isFalse);
  });

  test('both scopes needed for measurement', () {
    final s = ConsentStatus.fromLedger('1.0', [
      rec(ConsentScope.location, true, 1),
    ]);
    expect(s.decided, isFalse);
    expect(s.measurement, isFalse);
  });

  test('wire values round-trip', () {
    for (final s in ConsentScope.values) {
      expect(ConsentScope.fromWire(s.wireValue), s);
    }
    expect(ConsentScope.fromWire('x'), isNull);
  });

  test('permissions without consent cannot monitor or locate', () {
    const p = RadioPermissions(
      location: true,
      phoneState: true,
      hasTelephony: true,
      apiLevel: 34,
    );
    expect(p.canMonitor, isTrue);
    final off = p.withConsent(false);
    expect(off.canMonitor, isFalse);
    expect(off.canLocate, isFalse);
    expect(off.canDetectNsa, isTrue);
    expect(off.apiLevel, 34);
  });
}
