import 'dart:async';

import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/domain/repositories/voice_sms_repository.dart';

const smallVoiceSmsSettings = VoiceSmsSettings(
  callTargets: [PhoneTarget('Line A', '+67571234567')],
  smsTargets: [
    PhoneTarget('Me', '+67570000011', loopback: true),
    PhoneTarget('Line B', '+67571112222'),
  ],
  callWindowSeconds: 30,
  smsTimeoutSeconds: 20,
);

VoiceSmsResult callOk(PhoneTarget t) => VoiceSmsResult(
  kind: VoiceSmsKind.call,
  label: t.name,
  targetMasked: t.masked,
  status: TestStatus.ok,
  outcome: 'completed',
  windowS: 30,
  callMs: 30200,
  setupMs: 4200,
  connectedS: 26,
  dropped: false,
);

VoiceSmsResult smsOk(PhoneTarget t) => VoiceSmsResult(
  kind: VoiceSmsKind.sms,
  label: t.name,
  targetMasked: t.masked,
  status: TestStatus.ok,
  outcome: t.loopback ? 'received' : 'delivered',
  loopback: t.loopback,
  sendMs: 1200,
  deliveryMs: 3400,
  receiveMs: t.loopback ? 5100 : null,
);

/// Records calls; [gate] holds a call open.
class FakeVoiceSmsEngine implements VoiceSmsEngine {
  final calls = <String>[];
  Completer<void>? gate;
  int cancels = 0;
  int requests = 0;
  VoiceSmsPermissions perms = const VoiceSmsPermissions(
    call: true,
    endCall: true,
    callLog: true,
    sendSms: true,
    receiveSms: true,
  );

  @override
  Future<VoiceSmsPermissions> permissions() async => perms;

  @override
  Future<VoiceSmsPermissions> requestPermissions() async {
    requests++;
    return perms;
  }

  @override
  Future<VoiceSmsResult> call(PhoneTarget t, {required Duration window}) async {
    calls.add('call:${t.name}:${window.inSeconds}');
    await gate?.future;
    return callOk(t);
  }

  @override
  Future<VoiceSmsResult> sms(PhoneTarget t, {required Duration timeout}) async {
    calls.add('sms:${t.name}:${t.loopback}:${timeout.inSeconds}');
    await gate?.future;
    return smsOk(t);
  }

  @override
  Future<void> cancel() async => cancels++;
}
