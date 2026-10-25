import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';

/// Native call and SMS probes (MethodChannel `org.opennetiq/voice_sms`).
abstract interface class VoiceSmsEngine {
  Future<VoiceSmsPermissions> permissions();

  Future<VoiceSmsPermissions> requestPermissions();

  Future<VoiceSmsResult> call(PhoneTarget target, {required Duration window});

  Future<VoiceSmsResult> sms(PhoneTarget target, {required Duration timeout});

  Future<void> cancel();
}

abstract interface class VoiceSmsStore {
  Future<void> saveVoiceSmsTests(List<VoiceSmsRecord> records);

  Stream<List<VoiceSmsRecord>> watchVoiceSmsTests({int limit = 50});
}
