import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';

/// Native call and SMS probes (MethodChannel `org.opennetiq/voice_sms`).
abstract interface class VoiceSmsEngine {
  Future<VoiceSmsPermissions> permissions();

  Future<VoiceSmsPermissions> requestPermissions();

  /// Dials [target] and releases the call [setupTimeout] + [hold] after
  /// dialling; later setup = unsuccessful (`setup_timeout`).
  Future<VoiceSmsResult> call(
    PhoneTarget target, {
    required Duration setupTimeout,
    required Duration hold,
  });

  Future<VoiceSmsResult> sms(PhoneTarget target, {required Duration timeout});

  Future<void> cancel();
}

abstract interface class VoiceSmsStore {
  Future<void> saveVoiceSmsTests(List<VoiceSmsRecord> records);

  Stream<List<VoiceSmsRecord>> watchVoiceSmsTests({int limit = 50});
}
