import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/privacy.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';

ConsentStatus consentStatus({bool? measurement}) => ConsentStatus(
  policyVersion: privacyPolicyVersion,
  decisions: measurement == null
      ? const {}
      : {for (final s in ConsentScope.measurement) s: measurement},
);

/// In-memory consent; records decisions instead of writing the ledger.
class FakeConsentController extends ConsentController {
  FakeConsentController(this.initial);

  final ConsentStatus initial;
  final decisions = <bool>[];

  @override
  Future<ConsentStatus> build() async => initial;

  @override
  Future<void> setMeasurement({required bool granted}) async {
    decisions.add(granted);
    state = AsyncData(consentStatus(measurement: granted));
  }
}

/// Measurement consent already given (default for feature tests).
final grantedConsentOverride = consentProvider.overrideWith(
  () => FakeConsentController(consentStatus(measurement: true)),
);
