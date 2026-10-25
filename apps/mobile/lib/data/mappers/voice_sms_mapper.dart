import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';

/// Native result map (VoiceSmsBridge) -> [VoiceSmsResult].
abstract final class VoiceSmsMapper {
  static double? _d(Object? v) => v is num ? v.toDouble() : null;
  static int? _i(Object? v) => v is num ? v.toInt() : null;

  static VoiceSmsResult fromMap(
    VoiceSmsKind kind,
    PhoneTarget target,
    Map<Object?, Object?> m,
  ) => VoiceSmsResult(
    kind: kind,
    label: target.name,
    targetMasked: m['target_masked'] as String? ?? target.masked,
    status: TestStatus.fromWire(m['status'] as String?) ?? TestStatus.failed,
    outcome:
        m['outcome'] as String? ??
        (kind == VoiceSmsKind.call ? 'not_placed' : 'not_sent'),
    error: m['error'] as String?,
    windowS: _i(m['window_s']),
    callMs: _d(m['call_ms']),
    setupMs: _d(m['setup_ms']),
    connectedS: _i(m['connected_s']),
    dropped: m['dropped'] as bool?,
    voiceRat: m['voice_rat'] as String?,
    loopback: kind == VoiceSmsKind.sms
        ? (m['loopback'] as bool? ?? target.loopback)
        : null,
    sendMs: _d(m['send_ms']),
    deliveryMs: _d(m['delivery_ms']),
    receiveMs: _d(m['receive_ms']),
  );
}
