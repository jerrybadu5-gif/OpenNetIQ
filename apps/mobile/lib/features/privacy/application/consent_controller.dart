import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/privacy.dart';
import 'package:opennetiq_mobile/data/local/drift_consent_store.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/domain/repositories/consent_repository.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

final driftConsentStoreProvider = Provider<DriftConsentStore>(
  (ref) => DriftConsentStore(ref.watch(appDatabaseProvider)),
);

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ref.watch(driftConsentStoreProvider),
);

final measurementDataEraserProvider = Provider<MeasurementDataEraser>(
  (ref) => ref.watch(driftConsentStoreProvider),
);

/// Current consent for [privacyPolicyVersion] (issue #24, ADR-018).
class ConsentController extends AsyncNotifier<ConsentStatus> {
  @override
  Future<ConsentStatus> build() async => ConsentStatus.fromLedger(
    privacyPolicyVersion,
    await ref.watch(consentRepositoryProvider).ledger(),
  );

  /// Grants or withdraws radio + location measurement; logged either way.
  Future<void> setMeasurement({required bool granted}) async {
    await ref
        .read(consentRepositoryProvider)
        .record(
          ConsentScope.measurement,
          granted: granted,
          policyVersion: privacyPolicyVersion,
        );
    ref.invalidateSelf();
    await future;
  }

  /// Grants or withdraws the voice call and SMS tests; logged either way.
  Future<void> setVoiceSms({required bool granted}) async {
    await ref
        .read(consentRepositoryProvider)
        .record(
          {ConsentScope.voiceSms},
          granted: granted,
          policyVersion: privacyPolicyVersion,
        );
    ref.invalidateSelf();
    await future;
  }
}

final consentProvider = AsyncNotifierProvider<ConsentController, ConsentStatus>(
  ConsentController.new,
);

/// Radio and location collection allowed. False until the ledger is read,
/// so nothing is collected before consent is known.
final measurementConsentProvider = Provider<bool>(
  (ref) => ref.watch(consentProvider).value?.measurement ?? false,
);

/// Voice call and SMS tests allowed. False until the ledger is read.
final voiceSmsConsentProvider = Provider<bool>(
  (ref) => ref.watch(consentProvider).value?.voiceSms ?? false,
);

/// Ledger for the privacy screen, newest first.
final consentLedgerProvider = FutureProvider.autoDispose<List<ConsentRecord>>((
  ref,
) {
  ref.watch(consentProvider);
  return ref.watch(consentRepositoryProvider).ledger();
});
