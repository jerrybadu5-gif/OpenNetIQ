import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/voice_sms_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/domain/repositories/voice_sms_repository.dart';

class PlatformVoiceSmsEngine implements VoiceSmsEngine {
  const PlatformVoiceSmsEngine({MethodChannel channel = voiceSmsChannel})
    : this._(channel);

  const PlatformVoiceSmsEngine._(this._channel);

  static const MethodChannel voiceSmsChannel = MethodChannel(
    'org.opennetiq/voice_sms',
  );

  final MethodChannel _channel;

  Future<VoiceSmsPermissions> _perm(String method) async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>(method);
      return VoiceSmsPermissions.fromMap(m ?? const {});
    } on PlatformException {
      return const VoiceSmsPermissions();
    }
  }

  @override
  Future<VoiceSmsPermissions> permissions() => _perm('permissions');

  @override
  Future<VoiceSmsPermissions> requestPermissions() =>
      _perm('request_permissions');

  Future<VoiceSmsResult> _run(
    String method,
    Map<String, Object?> args,
    VoiceSmsKind kind,
    PhoneTarget t,
  ) async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>(method, args);
      return VoiceSmsMapper.fromMap(kind, t, m ?? const {});
    } on PlatformException catch (e) {
      return VoiceSmsMapper.fromMap(kind, t, {
        'status': 'failed',
        'error': e.message ?? e.code,
      });
    }
  }

  @override
  Future<VoiceSmsResult> call(PhoneTarget t, {required Duration window}) =>
      _run(
        'call',
        {'number': t.number, 'window_ms': window.inMilliseconds},
        VoiceSmsKind.call,
        t,
      );

  @override
  Future<VoiceSmsResult> sms(PhoneTarget t, {required Duration timeout}) =>
      _run(
        'sms',
        {
          'number': t.number,
          'loopback': t.loopback,
          'timeout_ms': timeout.inMilliseconds,
        },
        VoiceSmsKind.sms,
        t,
      );

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
