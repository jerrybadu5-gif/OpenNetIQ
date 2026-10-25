import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';

void main() {
  test('phone targets parse, validate and mask', () {
    final (list, errors) = PhoneTarget.parseLines(
      'Line A | +675 7123-4567\n\n | 7000 0011\nMe | 7000-0011 | self\n'
      'bad | hello',
    );
    expect(errors, ['Line 5: not a phone number']);
    expect(list.map((t) => t.name), ['Line A', 'Line ••11', 'Me']);
    expect(list.first.number, '+67571234567');
    expect(list.first.masked, '••67');
    expect(list.last.loopback, isTrue);
    expect(PhoneTarget.toLines(list.sublist(2)), 'Me | 70000011 | self');
    expect(PhoneTarget.maskNumber('1'), '••');
    expect(PhoneTarget.isValidNumber('*100#'), isTrue);
    expect(PhoneTarget.isValidNumber('12'), isFalse);
  });

  test('settings round-trip JSON with defaults', () {
    const s = VoiceSmsSettings(
      callTargets: [PhoneTarget('A', '123456')],
      smsTargets: [PhoneTarget('Me', '654321', loopback: true)],
      setupTimeoutSeconds: 15,
      holdSeconds: 60,
      intervalSeconds: 10,
      smsTimeoutSeconds: 30,
    );
    final back = VoiceSmsSettings.fromJson(s.toJson());
    expect(back.callTargets.single.number, '123456');
    expect(back.smsTargets.single.loopback, isTrue);
    expect(back.callWindowSeconds, 75);
    expect(back.totalCallWindowSeconds, 85);
    expect(back.intervalSeconds, 10);
    expect(back.smsTimeoutSeconds, 30);
    expect(back.targets(VoiceSmsKind.sms).single.name, 'Me');
    final empty = VoiceSmsSettings.fromJson(const {'call_targets': 'x'});
    expect(empty.callTargets, isEmpty);
    // NICTA QoS Rule 2022 Schedule 1 defaults: 20 + 120 + 30 = 170 s.
    expect(empty.setupTimeoutSeconds, 20);
    expect(empty.holdSeconds, 120);
    expect(empty.totalCallWindowSeconds, 170);
    expect(empty.smsTimeoutSeconds, 60);
    expect(s.copyWith(smsTimeoutSeconds: 9).smsTimeoutSeconds, 9);
    expect(VoiceSmsKind.fromWire('sms'), VoiceSmsKind.sms);
    expect(VoiceSmsKind.fromWire('x'), isNull);
  });

  test('summaries and setup success', () {
    const call = VoiceSmsResult(
      kind: VoiceSmsKind.call,
      label: 'A',
      targetMasked: '••67',
      status: TestStatus.failed,
      outcome: 'no_answer',
      connectedS: 0,
    );
    expect(call.summary, 'no answer');
    expect(call.setupSuccess, isFalse);
    const late = VoiceSmsResult(
      kind: VoiceSmsKind.call,
      label: 'A',
      targetMasked: '••67',
      status: TestStatus.failed,
      outcome: 'setup_timeout',
      setupMs: 25000,
      connectedS: 115,
    );
    expect(late.setupSuccess, isFalse);
    const sms = VoiceSmsResult(
      kind: VoiceSmsKind.sms,
      label: 'Me',
      targetMasked: '••11',
      status: TestStatus.ok,
      outcome: 'received',
      sendMs: 1200,
      deliveryMs: 3000,
      receiveMs: 4500,
    );
    expect(
      sms.summary,
      'received · sent 1.2 s · delivered 3.0 s · received 4.5 s',
    );
  });

  test('permissions map and voice_sms consent scope', () {
    final p = VoiceSmsPermissions.fromMap(const {
      'call': true,
      'end_call': true,
      'call_log': true,
      'send_sms': true,
      'receive_sms': true,
    });
    expect(p.all, isTrue);
    expect(p.hasTelephony, isTrue);
    expect(VoiceSmsPermissions.fromMap(const {'call': true}).all, isFalse);
    expect(ConsentScope.fromWire('voice_sms'), ConsentScope.voiceSms);
    final status = ConsentStatus.fromLedger('1.1', [
      ConsentRecord(
        id: '1',
        scope: ConsentScope.voiceSms,
        granted: true,
        policyVersion: '1.1',
        timestamp: DateTime.utc(2026),
      ),
    ]);
    expect(status.voiceSms, isTrue);
    expect(status.decided, isFalse); // voice/SMS alone is not onboarding
  });
}
