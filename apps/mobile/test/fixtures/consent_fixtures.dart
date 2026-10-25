import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/privacy.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';

ConsentStatus consentStatus({bool? measurement, bool? voiceSms}) =>
    ConsentStatus(
      policyVersion: privacyPolicyVersion,
      decisions: {
        if (measurement != null)
          for (final s in ConsentScope.measurement) s: measurement,
        ConsentScope.voiceSms: ?voiceSms,
      },
    );

/// In-memory consent; records decisions instead of writing the ledger.
class FakeConsentController extends ConsentController {
  FakeConsentController(this.initial);

  final ConsentStatus initial;
  final decisions = <bool>[];
  final voiceSmsDecisions = <bool>[];

  @override
  Future<ConsentStatus> build() async => initial;

  @override
  Future<void> setMeasurement({required bool granted}) async {
    decisions.add(granted);
    state = AsyncData(
      consentStatus(
        measurement: granted,
        voiceSms: state.value?.decisions[ConsentScope.voiceSms],
      ),
    );
  }

  @override
  Future<void> setVoiceSms({required bool granted}) async {
    voiceSmsDecisions.add(granted);
    state = AsyncData(
      consentStatus(measurement: state.value?.measurement, voiceSms: granted),
    );
  }
}

/// Measurement consent already given (default for feature tests).
final grantedConsentOverride = consentProvider.overrideWith(
  () => FakeConsentController(consentStatus(measurement: true)),
);

/// Measurement and voice/SMS consent given.
final voiceSmsConsentOverride = consentProvider.overrideWith(
  () => FakeConsentController(consentStatus(measurement: true, voiceSms: true)),
);
